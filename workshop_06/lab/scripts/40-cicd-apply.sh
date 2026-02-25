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
# git-clone a git-cli z openshift-pipelines očakávajú v basic-auth workspace
# súbor .git-credentials vo formáte: http://user:password@host
GITEA_INTERNAL_HOST="gitea-http.gitea.svc.cluster.local:3000"
GIT_CREDENTIALS_FILE=$(mktemp)
echo "http://${GITEA_ADMIN_USER}:${GITEA_HTTP_TOKEN}@${GITEA_INTERNAL_HOST}" > "${GIT_CREDENTIALS_FILE}"
GIT_CONFIG_FILE=$(mktemp)
cat <<EOF > "${GIT_CONFIG_FILE}"
[user]
   name = ${GITEA_ADMIN_USER}
   email = ${GITEA_ADMIN_USER}@example.com
[credential]
    helper = store
EOF

oc -n "${OCP_CICD_NAMESPACE}" delete secret gitea-credentials --ignore-not-found
oc -n "${OCP_CICD_NAMESPACE}" create secret generic gitea-credentials \
  --from-literal=username="${GITEA_ADMIN_USER}" \
  --from-literal=token="${GITEA_HTTP_TOKEN}" \
  --from-literal=password="${GITEA_HTTP_TOKEN}"  # alias pre git-clone basic-auth workspace

oc -n workshop-06-cicd delete secret gitea-basic-auth --ignore-not-found
oc -n workshop-06-cicd create secret generic gitea-basic-auth \
  --from-file=.git-credentials="${GIT_CREDENTIALS_FILE}" \
  --from-file=.gitconfig="${GIT_CONFIG_FILE}"  # git-clone basic-auth workspace očakáva .git-credentials a .gitconfig súbory
rm -f "${GIT_CREDENTIALS_FILE}" "${GIT_CONFIG_FILE}"

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
