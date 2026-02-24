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

# Developer může editovať zdroje v oboch namespacoch
oc adm policy add-role-to-user edit developer \
  -n "${OCP_CICD_NAMESPACE}" || true
oc adm policy add-role-to-user edit developer \
  -n "${OCP_APP_NAMESPACE}" || true

# Developer (a pipeline SA) môže pushovať image do OCP registra
oc adm policy add-role-to-user system:image-builder developer \
  -n "${OCP_CICD_NAMESPACE}" || true

# Umožní ArgoCD nasadzovať do app namespace
oc label namespace "${OCP_APP_NAMESPACE}" \
  argocd.argoproj.io/managed-by=openshift-gitops --overwrite

echo "[namespaces] Povolím interný OCP register (ak nie je povolený)..."
oc patch configs.imageregistry.operator.openshift.io/cluster \
  --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}' \
  --type=merge || true

# ServiceAccount pipeline v CICD namespace musí mať právo pushnutia do registra
# (pipeline SA je vytvorený automaticky OCP Pipelines operátorom)
# Čakáme kým SA existuje
echo "[namespaces] Čakám na pipeline ServiceAccount..."
for i in $(seq 1 20); do
  if oc get sa pipeline -n "${OCP_CICD_NAMESPACE}" >/dev/null 2>&1; then
    echo "  [ok] pipeline SA existuje"
    break
  fi
  sleep 5
done

oc adm policy add-role-to-user system:image-builder \
  -z pipeline -n "${OCP_CICD_NAMESPACE}" || true

echo "[ok] Namespaces a RBAC nastavené."
echo "     CICD: ${OCP_CICD_NAMESPACE}"
echo "     App:  ${OCP_APP_NAMESPACE}"
