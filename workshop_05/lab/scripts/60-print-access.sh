#!/usr/bin/env bash
set -euo pipefail

IP="$(minikube ip)"
echo ""
echo "=== ACCESS ==="
echo "Add to /etc/hosts:"
echo "${IP} ${GITEA_HOST} ${ARGOCD_HOST}"
echo ""
echo "Gitea: http://${GITEA_HOST}"
echo "  login: ${GITEA_ADMIN_USER} / ${GITEA_ADMIN_PASS}"
echo ""
echo "ArgoCD: http://${ARGOCD_HOST}"
echo "  login: admin"
ARGOCD_INIT_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo '<see kubectl -n argocd get secret argocd-initial-admin-secret>')"
echo "  initial password: ${ARGOCD_INIT_PASS}"
echo ""
