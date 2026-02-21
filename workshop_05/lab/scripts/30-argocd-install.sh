#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[wait] argocd pods..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

echo "[ok] argocd installed"

# Patch argocd-server to run in insecure mode (no TLS, offloaded to ingress).
# Container index 0 is the main argocd-server container per the official ArgoCD manifest.
kubectl -n argocd patch deployment argocd-server \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--insecure"}]'

kubectl -n argocd rollout status deploy/argocd-server --timeout=120s

echo "[ok] argocd server patched (insecure mode for ingress)"
