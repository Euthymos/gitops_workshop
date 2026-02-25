#!/usr/bin/env bash
# Vytvorí namespace-y pre CICD a aplikáciu. Nastaví RBAC pre developer účet.
set -euo pipefail

: "${OCP_CICD_NAMESPACE:?Set OCP_CICD_NAMESPACE in .env}"
: "${OCP_APP_NAMESPACE:?Set OCP_APP_NAMESPACE in .env}"
: "${OCP_REGISTRY:?Set OCP_REGISTRY in .env}"

echo "[namespaces] Vytváram namespace-y..."
oc create namespace "${OCP_CICD_NAMESPACE}" --dry-run=client -o yaml | oc apply -f -
oc create namespace "${OCP_APP_NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

echo "[namespaces] Nastavujem RBAC pre developer..."
oc adm policy add-role-to-user edit developer -n "${OCP_CICD_NAMESPACE}" || true
oc adm policy add-role-to-user edit developer -n "${OCP_APP_NAMESPACE}" || true
oc adm policy add-role-to-user system:image-builder developer -n "${OCP_CICD_NAMESPACE}" || true
oc adm policy add-role-to-user system:image-puller system:serviceaccount:workshop-06:default -n "${OCP_CICD_NAMESPACE}" || true
oc label namespace "${OCP_APP_NAMESPACE}" \
  argocd.argoproj.io/managed-by=openshift-gitops --overwrite

echo "[namespaces] Povolenie interného OCP registra..."
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}' \
  --type=merge || true

# pipeline SA je vytváraný automaticky OCP Pipelines operátorom – počkaj naň
echo "[namespaces] Čakám na pipeline ServiceAccount..."
for i in $(seq 1 20); do
  oc get sa pipeline -n "${OCP_CICD_NAMESPACE}" >/dev/null 2>&1 && break
  echo "  [wait] pipeline SA ($i/20)..."
  sleep 5
done

if ! oc get sa pipeline -n "${OCP_CICD_NAMESPACE}" >/dev/null 2>&1; then
  echo "[namespaces] pipeline SA neexistuje, vytváram ho explicitne..."
  oc create sa pipeline -n "${OCP_CICD_NAMESPACE}" >/dev/null
fi

# pipeline SA potrebuje: push do registra + privileged SCC pre buildah
oc adm policy add-role-to-user system:image-builder \
  -z pipeline -n "${OCP_CICD_NAMESPACE}" || true
oc adm policy add-scc-to-user privileged \
  -z pipeline -n "${OCP_CICD_NAMESPACE}"

echo "[ok] Namespaces a RBAC nastavené."
echo "     CICD: ${OCP_CICD_NAMESPACE}"
echo "     App:  ${OCP_APP_NAMESPACE}"
