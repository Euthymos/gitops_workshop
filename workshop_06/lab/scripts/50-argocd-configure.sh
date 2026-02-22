#!/usr/bin/env bash
# Nakonfiguruje ArgoCD: pridá Gitea repo a vytvorí ArgoCD projekt + aplikáciu.
set -euo pipefail

: "${GITEA_ADMIN_USER:?Set GITEA_ADMIN_USER in .env}"
: "${GITEA_ADMIN_PASS:?Set GITEA_ADMIN_PASS in .env}"
: "${GITEA_HOST:?Set GITEA_HOST in .env}"
: "${OCP_APP_NAMESPACE:?Set OCP_APP_NAMESPACE in .env}"

echo "[argocd] Získavam ArgoCD admin password..."
ARGOCD_PASS="$(oc get secret openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' | base64 -d)"

ARGOCD_SVC_HOST=$(oc get route openshift-gitops-server -n openshift-gitops \
  -o jsonpath='{.spec.host}')

echo "[argocd] Prihlasovanie na ArgoCD API (http://${ARGOCD_SVC_HOST})..."

# Port-forward pre API prístup
oc -n openshift-gitops port-forward svc/openshift-gitops-server 18080:80 &
PF_PID=$!
trap "kill ${PF_PID} 2>/dev/null || true; wait ${PF_PID} 2>/dev/null || true" EXIT

for i in $(seq 1 15); do
  curl -s http://localhost:18080/healthz >/dev/null 2>&1 && break
  sleep 2
done

SESSION_RESP=$(curl -s -X POST http://localhost:18080/api/v1/session \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"${ARGOCD_PASS}\"}")

ARGOCD_TOKEN=$(echo "${SESSION_RESP}" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("token",""))' \
  || { echo "[error] Nepodarilo sa získať ArgoCD token. Odpoveď: ${SESSION_RESP}"; exit 1; })

if [[ -z "$ARGOCD_TOKEN" ]]; then
  echo "[error] Prázdny ArgoCD token. Odpoveď: ${SESSION_RESP}"
  exit 1
fi

# Overenie: vytvor gitops-infra repo v Gitea (ak neexistuje)
GITEA_API="http://${GITEA_HOST}/api/v1"
echo "[argocd] Overujem existenciu gitops-infra repozitára v Gitea..."
curl -s -o /dev/null -w "%{http_code}" -X POST "${GITEA_API}/user/repos" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" \
  -H 'Content-Type: application/json' \
  -d '{"name":"gitops-infra","description":"GitOps infra repo","private":false,"auto_init":true,"default_branch":"main"}' || true

# Registruj gitops-infra repo v ArgoCD
echo "[argocd] Registrujem gitops-infra repozitár v ArgoCD..."
curl -s -o /dev/null -X POST "http://localhost:18080/api/v1/repositories" \
  -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "{
    \"repo\": \"http://${GITEA_HOST}/${GITEA_ADMIN_USER}/gitops-infra.git\",
    \"insecure\": true,
    \"username\": \"${GITEA_ADMIN_USER}\",
    \"password\": \"${GITEA_ADMIN_PASS}\"
  }" || true

echo "[ok] ArgoCD nakonfigurovaný."
echo "     URL: http://${ARGOCD_SVC_HOST}"
echo "     Admin password: ${ARGOCD_PASS}"
echo ""
echo "     Ďalší krok: Použi ArgoCD UI alebo aplikuj:"
echo "       oc apply -f manifests/argocd/project.yaml"
echo "       oc apply -f manifests/argocd/application.yaml"
