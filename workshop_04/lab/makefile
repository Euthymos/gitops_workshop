SHELL := /bin/bash

include .env
export

.PHONY: up down reset verify

up:
	@./scripts/00-check.sh
	@./scripts/10-minikube-up.sh
	@./scripts/20-registry-enable.sh
	@./scripts/30-tekton-install.sh
	@./scripts/40-gitea-install.sh
	@./scripts/50-cicd-apply.sh
	@./scripts/60-print-access.sh

down:
	minikube delete || true

reset: down up

verify:
	kubectl get pods -A
	kubectl -n tekton-pipelines get pods
	kubectl -n gitea get pods
	kubectl -n cicd get eventlistener,svc,pipeline
