SHELL := /bin/bash

include .env
export

.PHONY: up down reset verify

up:
	@./scripts/00-check.sh
	@./scripts/10-minikube-up.sh
	@./scripts/20-argocd-install.sh
	@./scripts/30-gitea-install.sh
	@./scripts/40-argocd-configure.sh
	@./scripts/50-print-access.sh

down:
	minikube delete || true

reset: down up

verify:
	kubectl get pods -A
	kubectl -n argocd get pods
	kubectl -n gitea get pods
