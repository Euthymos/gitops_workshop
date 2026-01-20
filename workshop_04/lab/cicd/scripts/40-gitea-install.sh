#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f manifests/namespaces.yaml

# admin secret (demo)
kubectl -n gitea apply -f manifests/gitea-admin-secret.yaml

helm repo add gitea-charts https://dl.gitea.io/charts/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install gitea gitea-charts/gitea \
  -n gitea \
  -f values/gitea-values.yaml

echo "[wait] gitea..."
kubectl -n gitea rollout status deploy/gitea --timeout=240s || true

echo "[ok] gitea installed"
