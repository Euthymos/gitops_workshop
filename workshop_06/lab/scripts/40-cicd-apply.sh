#!/usr/bin/env bash
# Aplikuje Tekton manifesty (tasks, pipeline, triggers, RBAC, PVC).
# Vyžaduje GITEA_HTTP_TOKEN nastavený v .env.
set -euo pipefail

: "${GITEA_HTTP_TOKEN:?Set GITEA_HTTP_TOKEN in .env – vygeneruj ho v Gitea UI}"
: "${GITEA_ADMIN_USER:?Set GITEA_ADMIN_USER in .env}"
: "${OCP_CICD_NAMESPACE:?Set OCP_CICD_NAMESPACE in .env}"
: "${OCP_APP_NAMESPACE:?Set OCP_APP_NAMESPACE in .env}"

echo "[cicd] Aplikujem CICD manifesty do namespace ${OCP_CICD_NAMESPACE}..."

# PVC pre zdieľaný workspace pipeline
oc apply -f manifests/tekton/workspace-pvc.yaml -n "${OCP_CICD_NAMESPACE}"

# RBAC pre pipeline SA a event listener SA
oc apply -f manifests/tekton/cicd-rbac.yaml -n "${OCP_CICD_NAMESPACE}"

# Secret s Gitea credentials (pre git clone a helm update tasky)
oc -n "${OCP_CICD_NAMESPACE}" delete secret gitea-credentials --ignore-not-found
oc -n "${OCP_CICD_NAMESPACE}" create secret generic gitea-credentials \
  --from-literal=username="${GITEA_ADMIN_USER}" \
  --from-literal=token="${GITEA_HTTP_TOKEN}"

# Tekton tasks, pipeline, triggers
oc apply -f manifests/tekton/tasks.yaml -n "${OCP_CICD_NAMESPACE}"
oc apply -f manifests/tekton/pipeline.yaml -n "${OCP_CICD_NAMESPACE}"
oc apply -f manifests/tekton/triggers-rbac.yaml -n "${OCP_CICD_NAMESPACE}"
oc apply -f manifests/tekton/triggers.yaml -n "${OCP_CICD_NAMESPACE}"

echo "[cicd] Čakám na EventListener..."
for i in $(seq 1 20); do
  if oc get deployment -l eventlistener=greeter-listener -n "${OCP_CICD_NAMESPACE}" >/dev/null 2>&1; then
    oc rollout status $(oc get deploy -l eventlistener=greeter-listener -n "${OCP_CICD_NAMESPACE}" -o name | head -1) \
      -n "${OCP_CICD_NAMESPACE}" --timeout=60s && break
  fi
  echo "  [wait] EventListener deployment ($i/20)..."
  sleep 5
done

# Vytvor Route pre EventListener (potrebná pre Gitea webhook)
EL_SVC=$(oc get svc -l eventlistener=greeter-listener -n "${OCP_CICD_NAMESPACE}" -o name | head -1 | cut -d/ -f2)
if [[ -n "$EL_SVC" ]]; then
  oc expose svc "${EL_SVC}" -n "${OCP_CICD_NAMESPACE}" --name=el-greeter-listener 2>/dev/null || true
fi

EL_ROUTE=$(oc get route el-greeter-listener -n "${OCP_CICD_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || true)
echo "[ok] CICD manifesty aplikované."
if [[ -n "$EL_ROUTE" ]]; then
  echo "     EventListener webhook URL: http://${EL_ROUTE}"
fi
