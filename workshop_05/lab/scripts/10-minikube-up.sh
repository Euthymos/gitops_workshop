#!/usr/bin/env bash
set -euo pipefail

minikube status >/dev/null 2>&1 || minikube start

minikube addons enable ingress

minikube addons enable metrics-server >/dev/null 2>&1 || true

echo "[ok] minikube up + ingress enabled"
