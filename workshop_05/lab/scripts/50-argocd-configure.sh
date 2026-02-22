#!/usr/bin/env bash
set -euo pipefail

: "${GITEA_ADMIN_PASS:?Set GITEA_ADMIN_PASS in .env}"
: "${GITEA_ADMIN_USER:?Set GITEA_ADMIN_USER in .env}"
: "${GITEA_HOST:?Set GITEA_HOST in .env}"
: "${ARGOCD_HOST:?Set ARGOCD_HOST in .env}"

# Register Gitea as a repository source in ArgoCD
# ArgoCD CLI is optional – we use kubectl + argocd API via port-forward in background
echo "[info] adding Gitea repo to ArgoCD..."

# Get the initial admin password
ARGOCD_INIT_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"

# Add Gitea repo via ArgoCD API (using kubectl port-forward)
kubectl -n argocd port-forward svc/argocd-server 18080:80 &
PF_PID=$!

# Wait until the port-forward is accepting connections
for i in $(seq 1 15); do
  curl -s http://localhost:18080/healthz >/dev/null 2>&1 && break
  sleep 2
done

SESSION_RESPONSE="$(curl -s -k -X POST http://localhost:18080/api/v1/session \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"${ARGOCD_INIT_PASS}\"}")"

ARGOCD_TOKEN="$(echo "${SESSION_RESPONSE}" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); t=d.get("token") or ""; print(t) if t else exit(1)' \
  || { echo "[error] failed to obtain ArgoCD token; response: ${SESSION_RESPONSE}"; kill "${PF_PID}"; exit 1; })"

# Create the gitops-infra repo in Gitea
GITEA_API="http://${GITEA_HOST}/api/v1"
curl -s -o /dev/null -X POST "${GITEA_API}/user/repos" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" \
  -H 'Content-Type: application/json' \
  -d '{"name":"gitops-infra","description":"GitOps infra repo","private":false,"auto_init":true,"default_branch":"main"}' || true

# Register repo in ArgoCD
curl -s -o /dev/null -X POST "http://localhost:18080/api/v1/repositories" \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "{\"repo\":\"http://${GITEA_HOST}/${GITEA_ADMIN_USER}/gitops-infra.git\",\"insecure\":true}"

kill "${PF_PID}" 2>/dev/null || true
wait "${PF_PID}" 2>/dev/null || true

# Apply ingresses
kubectl apply -f manifests/ingresses.yaml

echo "[ok] argocd configured (repo added, ingresses applied)"
