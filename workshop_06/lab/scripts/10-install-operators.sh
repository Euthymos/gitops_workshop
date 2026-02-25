#!/usr/bin/env bash
# Inštaluje OpenShift Pipelines a OpenShift GitOps operátory cez OperatorHub Subscriptions.
# Vyžaduje admin prístup.
set -euo pipefail

echo "[operators] Inštalujem OpenShift Pipelines a OpenShift GitOps operátory..."

# ── OpenShift Pipelines ──────────────────────────────────────────────────────
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# ── OpenShift GitOps ─────────────────────────────────────────────────────────
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "[operators] Subscriptions aplikované. Čakám na inštaláciu operátorov..."

# Čakaj na OpenShift Pipelines controller
for i in $(seq 1 30); do
  if oc get deployment tekton-pipelines-controller -n openshift-pipelines >/dev/null 2>&1; then
    oc rollout status deploy/tekton-pipelines-controller -n openshift-pipelines --timeout=120s && break
  fi
  echo "  [wait] openshift-pipelines ($i/30)..."
  sleep 10
done

# Čakaj na OpenShift GitOps server
for i in $(seq 1 30); do
  if oc get deployment openshift-gitops-server -n openshift-gitops >/dev/null 2>&1; then
    oc rollout status deploy/openshift-gitops-server -n openshift-gitops --timeout=180s && break
  fi
  echo "  [wait] openshift-gitops ($i/30)..."
  sleep 10
done

echo "[ok] Operátory nainštalované."
