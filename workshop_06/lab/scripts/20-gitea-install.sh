#!/usr/bin/env bash
# Nainštaluje Gitea pomocou Helm chartu na OCP.
set -euo pipefail

: "${GITEA_ADMIN_USER:?Set GITEA_ADMIN_USER in .env}"
: "${GITEA_ADMIN_PASS:?Set GITEA_ADMIN_PASS in .env}"

echo "[gitea] Vytváram namespace gitea..."
oc create namespace gitea --dry-run=client -o yaml | oc apply -f -

echo "[gitea] Udelujem anyuid SCC servisnému účtu Gitea..."
# Gitea pod beží ako UID 1000 – na OCP je potrebný anyuid SCC.
oc adm policy add-scc-to-user anyuid -z default -n gitea

echo "[gitea] Pridávam Helm repozítár Gitea..."
helm repo add gitea-charts https://dl.gitea.com/charts/ --force-update
helm repo update

echo "[gitea] Inštalujem Gitea..."
helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea \
  --values values/gitea-values.yaml \
  --set gitea.admin.username="${GITEA_ADMIN_USER}" \
  --set gitea.admin.password="${GITEA_ADMIN_PASS}" \
  --set gitea.admin.email="${GITEA_ADMIN_USER}@example.com" \
  --wait --timeout=300s

echo "[gitea] Čakám na Gitea deployment..."
oc rollout status deploy/gitea -n gitea --timeout=180s

echo "[gitea] Vytvárám Route pre Gitea..."
if ! oc get route gitea -n gitea >/dev/null 2>&1; then
  oc expose svc gitea-http -n gitea --name=gitea
fi

GITEA_HOST=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')
echo "[ok] Gitea dostupná na: http://${GITEA_HOST}"
echo "     Admin: ${GITEA_ADMIN_USER} / ${GITEA_ADMIN_PASS}"
