#!/usr/bin/env bash
set -euo pipefail

IP="$(minikube ip)"
echo ""
echo "=== ACCESS ==="
echo "Add to /etc/hosts:"
echo "${IP} ${GITEA_HOST}"
echo ""
echo "Gitea: http://${GITEA_HOST}"
echo "Tekton EventListener (cluster internal for Gitea webhook):"
echo "  http://el-gitea-listener.cicd.svc.cluster.local:8080"
echo ""
echo "Minikube registry (cluster internal):"
echo "  registry.kube-system.svc.cluster.local:5000"
echo ""
