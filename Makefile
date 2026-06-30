# ============================================
# TSA Capstone Phoenix - Root Makefile
# ============================================
# Orchestrates all infrastructure and application deployment
# Usage: make <target> ENV=<dev|prod> [CLOUD=<aws|local>]

SHELL := /bin/bash
ROOT_DIR := $(shell pwd)

# Include common variables and utilities first
include makefiles/common.mk

# Include System Lifecycle commands right after common
include makefiles/shutdown.mk
include makefiles/startup.mk

# Include all modular makefiles
include makefiles/ansible/ansible.mk
include makefiles/argo/install.mk
include makefiles/argo/access.mk
include makefiles/argo/sync.mk
include makefiles/argo/management.mk
include makefiles/k8s/cluster.mk
include makefiles/k8s/ingress.mk
include makefiles/k8s/cert-manager.mk
include makefiles/k8s/tls.mk
include makefiles/helm/app.mk
include makefiles/helm/testing.mk
include makefiles/helm/argo.mk
include makefiles/terraform/infra.mk
include makefiles/cicd/pipeline.mk
include makefiles/monitoring/stack.mk
include makefiles/secrets/sealed.mk
include makefiles/diag/cluster.mk
include makefiles/diag/tls.mk

# ============================================
# Full Deployment Pipelines
# ============================================
.PHONY: local-up
local-up: ## Full local deployment (k3d + all components)
	@echo "$(GREEN)🚀 Starting local deployment...$(RESET)"
	@$(MAKE) k8s-create ENV=dev CLOUD=local
	@$(MAKE) k8s-ingress-install
	@$(MAKE) helm-deploy ENV=dev
	@$(MAKE) helm-test-app ENV=dev
	@echo "$(GREEN)✅ Local deployment complete!$(RESET)"
	@echo "$(YELLOW)Access: http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)$(RESET)"

.PHONY: cloud-up
cloud-up: ## Full cloud deployment (AWS + k3s + all components)
	@echo "$(GREEN)🚀 Starting cloud deployment...$(RESET)"
	@$(MAKE) tf-apply ENV=prod
	@$(MAKE) ans-run ENV=prod
	@$(MAKE) k8s-context ENV=prod CLOUD=aws
	@$(MAKE) k8s-ingress-install
	@$(MAKE) helm-deploy-cloud ENV=prod
	@$(MAKE) helm-test-app ENV=prod
	@echo "$(GREEN)✅ Cloud deployment complete!$(RESET)"
	@echo "$(YELLOW)Access: https://$(HOST)$(RESET)"

.PHONY: local-down
local-down: ## Destroy local environment
	@echo "$(RED)💥 Destroying local cluster...$(RESET)"
	@$(MAKE) k8s-delete ENV=dev
	@echo "$(GREEN)✅ Local environment destroyed$(RESET)"

.PHONY: cloud-down
cloud-down: ## Destroy cloud environment
	@echo "$(RED)💥 Destroying cloud infrastructure...$(RESET)"
	@$(MAKE) tf-destroy ENV=prod
	@echo "$(GREEN)✅ Cloud infrastructure destroyed$(RESET)"

# ============================================
# Convenience Aliases & Pipelines
# ============================================
.PHONY: app-deploy app-status app-rollback app-uninstall
app-deploy: helm-deploy ## Deploy application (alias)
app-status: helm-status ## Check application status (alias)
app-rollback: helm-rollback ## Rollback application (alias)
app-uninstall: helm-uninstall ## Uninstall application (alias)

.PHONY: secrets-setup
secrets-setup: sec-install-controller sec-generate sec-inject-cluster
	@echo "$(GREEN)✅ Secrets setup complete!$(RESET)"

.PHONY: secrets-rotate
secrets-rotate:
	@rm -f .secrets/$(ENV).env
	@$(MAKE) secrets-setup ENV=$(ENV)

.PHONY: ci-local ci-cloud
ci-local: ## Full local CI/CD pipeline
	@$(MAKE) local-up && $(MAKE) helm-test-app ENV=dev

ci-cloud: ## Full cloud CI/CD pipeline
	@$(MAKE) cloud-up && $(MAKE) helm-test-app ENV=prod

.PHONY: tls-setup tls-status tls-verify
tls-setup: ## Install cert-manager and apply ClusterIssuer
	@$(MAKE) k8s-cert-install && $(MAKE) k8s-issuer-apply-retry
tls-status: ## Show TLS status
	@$(MAKE) k8s-cert-status && $(MAKE) k8s-issuer-status
tls-verify: ## Verify full TLS setup
	@$(MAKE) diag-tls

# ============================================
# Help System
# ============================================
.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)TaskApp Makefile Help$(RESET)"
	@echo "$(YELLOW)Usage: make [target] [VARIABLE=value]$(RESET)"
	@echo "$(CYAN)Environment Variables:$(RESET) ENV, CLOUD, NAMESPACE, HOST"
	@echo ""
	@$(MAKE) --no-print-directory help-common
	@echo ""
	@$(MAKE) --no-print-directory help-sys-startup
	@$(MAKE) --no-print-directory help-sys-shutdown
	@echo ""
	@$(MAKE) --no-print-directory help-terraform
	@$(MAKE) --no-print-directory help-ansible
	@echo ""
	@$(MAKE) --no-print-directory help-k8s-cluster
	@$(MAKE) --no-print-directory help-k8s-ingress
	@$(MAKE) --no-print-directory help-k8s-cert
	@$(MAKE) --no-print-directory help-k8s-tls
	@echo ""
	@$(MAKE) --no-print-directory help-helm-app
	@$(MAKE) --no-print-directory help-helm-testing
	@$(MAKE) --no-print-directory help-helm-argo
	@echo ""
	@$(MAKE) --no-print-directory help-argo-install
	@$(MAKE) --no-print-directory help-argo-access
	@$(MAKE) --no-print-directory help-argo-sync
	@$(MAKE) --no-print-directory help-argo-management
	@echo ""
	@$(MAKE) --no-print-directory help-monitoring
	@$(MAKE) --no-print-directory help-cicd
	@$(MAKE) --no-print-directory help-secrets
	@echo ""
	@$(MAKE) --no-print-directory help-diag-cluster
	@$(MAKE) --no-print-directory help-diag-tls
	@echo ""
	@echo "$(CYAN)Domain-Specific Help:$(RESET)"
	@echo "  make help-argo     Show all ArgoCD commands"
	@echo "  make help-k8s      Show all Kubernetes commands"
	@echo "  make help-helm     Show all Helm commands"
	@echo "  make help-diag     Show all Diagnostics commands"

# Domain aggregators for specific help
.PHONY: help-argo help-k8s help-helm help-diag
help-argo:
	@$(MAKE) --no-print-directory help-argo-install
	@$(MAKE) --no-print-directory help-argo-access
	@$(MAKE) --no-print-directory help-argo-sync
	@$(MAKE) --no-print-directory help-argo-management

help-k8s:
	@$(MAKE) --no-print-directory help-k8s-cluster
	@$(MAKE) --no-print-directory help-k8s-ingress
	@$(MAKE) --no-print-directory help-k8s-cert
	@$(MAKE) --no-print-directory help-k8s-tls

help-helm:
	@$(MAKE) --no-print-directory help-helm-app
	@$(MAKE) --no-print-directory help-helm-testing
	@$(MAKE) --no-print-directory help-helm-argo

help-diag:
	@$(MAKE) --no-print-directory help-diag-cluster
	@$(MAKE) --no-print-directory help-diag-tls

.DEFAULT_GOAL := help
