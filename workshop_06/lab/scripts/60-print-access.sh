#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  WORKSHOP 06 – Prihlasovacie údaje a URL"
echo "════════════════════════════════════════════════════════════"

GITEA_ROUTE=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
ARGOCD_PASS=$(oc get secret openshift-gitops-cluster -n openshift-gitops \
  -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d || echo "N/A")
TEKTON_DASH=$(oc get route tekton-dashboard -n openshift-pipelines -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
EL_ROUTE=$(oc get route el-greeter-listener -n "${OCP_CICD_NAMESPACE:-workshop-06-cicd}" \
  -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")
GREETER_ROUTE=$(oc get route -n "${OCP_APP_NAMESPACE:-workshop-06}" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "N/A")

echo ""
echo "  Gitea:"
echo "    URL:      http://${GITEA_ROUTE}"
echo "    Admin:    ${GITEA_ADMIN_USER:-gitea-admin} / ${GITEA_ADMIN_PASS:-<pozri .env>}"
echo ""
echo "  ArgoCD:"
echo "    URL:      https://${ARGOCD_ROUTE}"
echo "    Admin:    admin / ${ARGOCD_PASS}"
echo ""
echo "  Tekton Dashboard:"
echo "    URL:      http://${TEKTON_DASH}"
echo ""
echo "  EventListener Webhook URL (zadaj do Gitea):"
echo "    http://${EL_ROUTE}"
echo ""
echo "  Greeter aplikácia:"
echo "    http://${GREETER_ROUTE}"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  CRC konzola:   crc console"
echo "  CRC prístupy:  crc console --credentials"
echo "════════════════════════════════════════════════════════════"
echo ""
