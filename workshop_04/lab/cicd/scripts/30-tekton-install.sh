#!/usr/bin/env bash
set -euo pipefail

# Tekton Pipelines + Triggers (latest)
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

echo "[wait] tekton pods..."
kubectl -n tekton-pipelines rollout status deploy/tekton-pipelines-controller --timeout=180s
kubectl -n tekton-pipelines rollout status deploy/tekton-triggers-controller --timeout=180s || true

echo "[ok] tekton installed"
