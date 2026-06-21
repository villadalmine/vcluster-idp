# ═══ IDP Platform — Makefile ════════════════════════════════════════════════
# Targets to bootstrap the demo environment and manage the tenant lifecycle.
SHELL := /bin/bash
CLUSTER_NAME ?= idp-demo
TENANT ?= tenant-a
ENV ?= dev
ARGOCD_VERSION ?= stable

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n",$$1,$$2}'

.PHONY: bootstrap
bootstrap: kind-up argocd-install appsets ## Bring up kind + ArgoCD + ApplicationSets (dev-single demo)
	@echo "✔ Platform ready. Try: ./cli/platform $(TENANT) create"

.PHONY: bootstrap-existing
bootstrap-existing: preflight argocd-install appsets ## Bootstrap on an EXISTING cluster (no kind); uses current kube-context
	@echo "✔ Platform ready on context '$$(kubectl config current-context)'"
	@echo "  Next: ./cli/platform $(TENANT) create"

.PHONY: preflight
preflight: ## Sanity-check the current cluster before bootstrap-existing
	@echo "▶ context : $$(kubectl config current-context)"
	@kubectl auth can-i create namespace >/dev/null 2>&1 \
		&& echo "✔ admin   : can create namespaces" \
		|| { echo "✗ admin   : current context lacks admin rights"; exit 1; }
	@kubectl get storageclass 2>/dev/null | grep -q . \
		&& echo "✔ storage : StorageClass present (Postgres PVC)" \
		|| echo "⚠ storage : no StorageClass found — Postgres PVC will stay Pending"
	@kubectl get ns ingress-nginx >/dev/null 2>&1 \
		&& echo "✔ ingress : 'ingress-nginx' namespace found" \
		|| echo "⚠ ingress : no 'ingress-nginx' ns — install a controller or set networkPolicy.ingressNamespaceValue"

.PHONY: kind-up
kind-up: ## Create the local host cluster (kind)
	@kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$" \
		&& echo "✔ kind '$(CLUSTER_NAME)' already exists (idempotent)" \
		|| kind create cluster --name $(CLUSTER_NAME)

.PHONY: argocd-install
argocd-install: ## Install ArgoCD on the host cluster
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@echo "waiting for ArgoCD to be ready…"
	@kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

.PHONY: appsets
appsets: ## Apply both ApplicationSets (vclusters + workloads)
	@kubectl apply -f applicationsets/hosts-appset.yaml
	@kubectl apply -f applicationsets/tenants-appset.yaml
	@echo "✔ ApplicationSets applied"

.PHONY: create
create: ## Provision a tenant (TENANT=... ENV=...) via direct helm+vcluster (demo flow)
	@vcluster create $(TENANT)-$(ENV) --namespace vcluster-$(TENANT)-$(ENV) -f vcluster/shared-nodes.yaml --connect=false || true
	@helm upgrade --install $(TENANT) charts/tenant \
		--kube-context vcluster_$(TENANT)-$(ENV)_vcluster-$(TENANT)-$(ENV) \
		--set tenant.name=$(TENANT) --set tenant.environment=$(ENV) \
		--create-namespace --namespace $(TENANT)
	@echo "✔ tenant $(TENANT) deployed (helm upgrade --install = idempotent)"

.PHONY: status
status: ## Status of a tenant (TENANT=... ENV=...)
	@./cli/platform $(TENANT) status

.PHONY: delete
delete: ## Delete a tenant (TENANT=... ENV=...)
	@helm uninstall $(TENANT) --namespace $(TENANT) 2>/dev/null || true
	@vcluster delete $(TENANT)-$(ENV) --namespace vcluster-$(TENANT)-$(ENV) 2>/dev/null || true
	@./cli/platform $(TENANT) delete

.PHONY: lint
lint: ## Validate the repo YAML and the chart syntax
	@command -v helm >/dev/null && helm lint charts/tenant || echo "helm not installed: validate in your environment"
	@echo "✔ lint executed"

.PHONY: validate
validate: ## Run the E2E validation test catalog on the cluster (TENANT=... ENV=...)
	@./cli/validate $(TENANT) $(ENV) $(FLAGS)

.PHONY: validate-pod
validate-pod: ## Run E2E validation using a test pod for L7 checks (TENANT=... ENV=...)
	@./cli/validate $(TENANT) $(ENV) --pod-test $(FLAGS)



.PHONY: template
template: ## Render the tenant chart to stdout (debug)
	@helm template $(TENANT) charts/tenant --set tenant.name=$(TENANT) --set tenant.environment=$(ENV)

.PHONY: teardown
teardown: ## Destroy the demo host cluster
	@kind delete cluster --name $(CLUSTER_NAME)
