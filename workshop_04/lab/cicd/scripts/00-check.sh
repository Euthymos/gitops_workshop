#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

need minikube
need kubectl
need helm
need git

echo "[ok] tools present"
