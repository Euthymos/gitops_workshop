SHELL := /bin/bash

include .env
export

.PHONY: admin-up cicd-up admin-down verify info

## ── Admin ──────────────────────────────────────────────────────────────────

# Krok 1: nastav klaster (operátory, Gitea, namespaces + RBAC)
# Spusti PRED vytvorením Gitea tokenu.
admin-up:
	@./scripts/00-check.sh
	@./scripts/10-install-operators.sh
	@./scripts/20-gitea-install.sh
	@./scripts/30-setup-namespaces.sh
	@./scripts/60-print-access.sh

# Krok 2: aplikuj CICD manifesty a nakonfiguruj ArgoCD
# Spusti PO vytvorení Gitea tokenu a doplnení GITEA_HTTP_TOKEN do .env.
cicd-up:
	@./scripts/40-cicd-apply.sh
	@./scripts/50-argocd-configure.sh
	@./scripts/60-print-access.sh

admin-down:
	oc delete namespace $(OCP_CICD_NAMESPACE) --ignore-not-found
	oc delete namespace $(OCP_APP_NAMESPACE) --ignore-not-found
	helm uninstall gitea -n gitea --ignore-not-found || true

## ── Info & Verify ──────────────────────────────────────────────────────────

verify:
	@echo "=== Nodes ==="
	oc get nodes
	@echo "=== OpenShift Pipelines ==="
	oc get pods -n openshift-pipelines | head -10
	@echo "=== OpenShift GitOps ==="
	oc get pods -n openshift-gitops | head -10
	@echo "=== Gitea ==="
	oc get pods -n gitea
	@echo "=== CICD namespace ==="
	oc get eventlistener,pipeline,pvc -n $(OCP_CICD_NAMESPACE)
	@echo "=== App namespace ==="
	oc get all -n $(OCP_APP_NAMESPACE)

info:
	@./scripts/60-print-access.sh
