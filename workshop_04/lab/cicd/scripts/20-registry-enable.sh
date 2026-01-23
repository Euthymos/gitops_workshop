#!/usr/bin/env bash
set -euo pipefail

minikube addons enable registry
minikube addons enable registry-aliases >/dev/null 2>&1 || true

echo "[ok] minikube registry enabled"
kubectl -n kube-system get svc registry || true
