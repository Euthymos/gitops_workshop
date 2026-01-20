#!/usr/bin/env bash
set -euo pipefail

: "${GITEA_HTTP_TOKEN:?Set GITEA_HTTP_TOKEN in .env}"

kubectl apply -f manifests/tekton/workspace-pvc.yaml
kubectl apply -f manifests/tekton/cicd-rbac.yaml

# secret pre git token (pipeline tasky)
kubectl -n cicd delete secret gitea-credentials >/dev/null 2>&1 || true
kubectl -n cicd create secret generic gitea-credentials \
  --from-literal=username="${GITEA_ADMIN_USER}" \
  --from-literal=token="${GITEA_HTTP_TOKEN}"

kubectl apply -f manifests/tekton/tasks-pipeline.yaml
kubectl apply -f manifests/tekton/triggers-rbac.yaml
kubectl apply -f manifests/tekton/triggers.yaml

echo "[ok] cicd manifests applied"
