SHELL := /usr/bin/env bash
KUBECONFIG_FILE := $(CURDIR)/.kube/kubeconfig.yaml
export KUBECONFIG := $(KUBECONFIG_FILE)

.PHONY: up down password port-forward status clean reset

up:
	docker compose up -d
	@echo "Waiting for kubeconfig..."
	@until [ -f $(KUBECONFIG_FILE) ]; do sleep 2; done
	@./bootstrap/install-argocd.sh

down:
	docker compose down

reset: clean up

clean:
	docker compose down -v
	rm -rf .kube

password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d && echo

port-forward:
	kubectl port-forward -n argocd svc/argocd-server 8080:443

status:
	kubectl get applications -n argocd
	@echo
	kubectl get pods -A | grep -E 'argocd|argo-rollouts|stage[0-9]' || true
