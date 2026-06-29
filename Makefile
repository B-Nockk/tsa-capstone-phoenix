# ============================================
# TSA Capstone Phoenix - Root Makefile
# ============================================
# Orchestrates all infrastructure and application deployment
# Usage: make <target> ENV=<dev|prod> [CLOUD=<aws|local>]

SHELL := /bin/bash
ROOT_DIR := $(shell pwd)

# Include all modular makefiles
include makefiles/common.mk
include makefiles/terraform.mk
include makefiles/ansible.mk
include makefiles/kubernetes.mk
include makefiles/helm.mk
include makefiles/gitops.mk
include makefiles/monitoring.mk
include makefiles/ci-cd.mk
include makefiles/secrets.mk
include makefiles/diagnostics.mk

# ============================================
# Full Deployment Pipelines
# ============================================

.PHONY: local-up
local-up: ## Full local deployment (k3d + all components)
	@echo "$(GREEN)🚀 Starting local deployment...$(RESET)"
	@$(MAKE) cluster-create ENV=dev CLOUD=local
	@$(MAKE) ingress-install
	@$(MAKE) helm-deploy ENV=dev
	@$(MAKE) app-test ENV=dev
	@echo "$(GREEN)✅ Local deployment complete!$(RESET)"
	@echo "$(YELLOW)Access: http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)$(RESET)"

.PHONY: cloud-up
cloud-up: ## Full cloud deployment (AWS + k3s + all components)
	@echo "$(GREEN)🚀 Starting cloud deployment...$(RESET)"
	@$(MAKE) infra-apply ENV=prod
	@$(MAKE) ansible-run ENV=prod
	@$(MAKE) cluster-context ENV=prod CLOUD=aws
	@$(MAKE) ingress-install
	@$(MAKE) helm-deploy-cloud ENV=prod
	@$(MAKE) app-test ENV=prod
	@echo "$(GREEN)✅ Cloud deployment complete!$(RESET)"
	@echo "$(YELLOW)Access: https://$(HOST)$(RESET)"

.PHONY: local-down
local-down: ## Destroy local environment
	@echo "$(RED)💥 Destroying local cluster...$(RESET)"
	@$(MAKE) cluster-delete ENV=dev
	@echo "$(GREEN)✅ Local environment destroyed$(RESET)"

.PHONY: cloud-down
cloud-down: ## Destroy cloud environment
	@echo "$(RED)💥 Destroying cloud infrastructure...$(RESET)"
	@$(MAKE) infra-destroy ENV=prod
	@echo "$(GREEN)✅ Cloud infrastructure destroyed$(RESET)"

# ============================================
# Convenience Aliases
# ============================================

.PHONY: app-deploy
app-deploy: helm-deploy ## Deploy application (alias)

.PHONY: app-status
app-status: helm-status ## Check application status (alias)

.PHONY: app-rollback
app-rollback: helm-rollback ## Rollback application (alias)

.PHONY: app-uninstall
app-uninstall: helm-uninstall ## Uninstall application (alias)

# ============================================
# secrets Commands
# ============================================

.PHONY: secrets-setup
secrets-setup: secrets-install-controller secrets-generate secrets-inject-cluster
	@echo "$(GREEN)✅ Secrets setup complete!$(RESET)"
	@echo "$(YELLOW)Next: Commit gitops/sealed-secrets/$(ENV)/sealed-secret.yaml$(RESET)"

.PHONY: secrets-rotate
secrets-rotate:
	@echo "$(YELLOW)🔄 Rotating secrets for $(ENV)...$(RESET)"
	@rm -f .secrets/$(ENV).env
	@$(MAKE) secrets-setup ENV=$(ENV)
	@echo "$(GREEN)✅ Secrets rotated!$(RESET)"

# ============================================
# CI/CD Pipelines (Single Command)
# ============================================

.PHONY: ci-local
ci-local: ## Full local CI/CD pipeline (idempotent)
	@echo "$(GREEN)🏗️  Running local CI/CD pipeline...$(RESET)"
	@$(MAKE) local-up || (echo "$(RED)❌ Deployment failed$(RESET)" && exit 1)
	@$(MAKE) app-test ENV=dev || (echo "$(RED)❌ Tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✅ CI/CD pipeline passed!$(RESET)"

.PHONY: ci-cloud
ci-cloud: ## Full cloud CI/CD pipeline (idempotent)
	@echo "$(GREEN)🏗️  Running cloud CI/CD pipeline...$(RESET)"
	@$(MAKE) cloud-up || (echo "$(RED)❌ Deployment failed$(RESET)" && exit 1)
	@$(MAKE) app-test ENV=prod || (echo "$(RED)❌ Tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✅ CI/CD pipeline passed!$(RESET)"

# ============================================
# Default target
# ============================================

.DEFAULT_GOAL := help
