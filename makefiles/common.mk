# ============================================
# common.mk - Common utilities and variables
# ============================================
GREEN  := $(shell tput -Txterm setaf 2 2>/dev/null || echo "")
YELLOW := $(shell tput -Txterm setaf 3 2>/dev/null || echo "")
RED    := $(shell tput -Txterm setaf 1 2>/dev/null || echo "")
BLUE   := $(shell tput -Txterm setaf 4 2>/dev/null || echo "")
CYAN   := $(shell tput -Txterm setaf 6 2>/dev/null || echo "")
RESET  := $(shell tput -Txterm sgr0 2>/dev/null || echo "")

ENV              	?= dev
CLOUD            	?= local
HOST             	?= taskapp.local
NAMESPACE 		 	?= taskapp-$(ENV)
PROJECT_NAME     	?= taskapp
CI               	?= false

ROOT_DIR         	:= $(shell pwd)
INFRA_DIR        	?= infra
TERRAFORM_DIR    	?= $(INFRA_DIR)/terraform
ANSIBLE_DIR      	?= $(INFRA_DIR)/ansible
MANIFESTS_DIR    	?= manifests
HELM_DIR         	?= helm/taskapp
GITOPS_DIR       	?= gitops
SECRETS_DIR      	?= .secrets
LOGS_DIR         	?= logs

LOCAL_SECRETS    	:= $(SECRETS_DIR)/$(ENV).env
HELM_VALUES_FILE 	:= $(HELM_DIR)/values-$(ENV).yaml

# Add these variables to common.mk if not already there
SSH_PRIVATE_KEY_PATH ?= ~/.ssh/tsa-capstone/tsa-capstone-project
SSH_PUBLIC_KEY_PATH  ?= ~/.ssh/tsa-capstone/tsa-capstone-project.pub

define check_cmd
	@command -v $(1) >/dev/null 2>&1 || { echo "$(RED)❌ $(1) not found$(RESET)"; exit 1; }
endef

.PHONY: help-common
help-common:
	@echo "$(CYAN)Common Targets:$(RESET)"
	@echo "  help                 Show this help message"
	@echo "  check-tools          Check if required tools are installed"
	@echo "  version              Show version information"
	@echo "  setup                Complete project setup"

.PHONY: check-tools
check-tools: ## Check if required tools are installed
	@echo "$(YELLOW)🔍 Checking required tools...$(RESET)"
	$(call check_cmd,terraform)
	$(call check_cmd,ansible)
	$(call check_cmd,kubectl)
	$(call check_cmd,helm)
	$(call check_cmd,k3d)
	$(call check_cmd,kubeseal)
	$(call check_cmd,htpasswd)
	@echo "$(GREEN)✅ All tools installed$(RESET)"

.PHONY: version
version: ## Show version information
	@echo "Project: $(PROJECT_NAME) | Env: $(ENV) | Cloud: $(CLOUD)"

.PHONY: setup
setup: ## Complete project setup (create directories)
	@mkdir -p $(SECRETS_DIR) $(LOGS_DIR)
	@echo "$(GREEN)✓ Project structure created$(RESET)"

.PHONY: ssh-key-setup
ssh-key-setup: ## Generate SSH key if it doesn't exist (no passphrase for CI)
	@mkdir -p $(dir $(SSH_PRIVATE_KEY_PATH))
	@if [ ! -f "$(SSH_PRIVATE_KEY_PATH)" ]; then \
		echo "$(YELLOW)🔑 Generating SSH key at $(SSH_PRIVATE_KEY_PATH)...$(RESET)"; \
		ssh-keygen -t ed25519 -f $(SSH_PRIVATE_KEY_PATH) -N ""; \
		echo "$(GREEN)✅ SSH key generated (No passphrase for CI compatibility)$(RESET)"; \
	else \
		echo "$(GREEN)✅ SSH key already exists$(RESET)"; \
	fi

.PHONY: setup-ci-deps
setup-ci-deps: ## Install all required tools for CI/CD runners (Ubuntu)
	@echo "$(GREEN)📦 Installing CI dependencies...$(RESET)"
	@sudo apt-get update -qq
	@sudo apt-get install -y -qq apache2-utils jq unzip

	@# kubectl
	@echo "  Installing kubectl..."
	@curl -sLO "https://dl.k8s.io/release/$$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	@sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

	@# helm
	@echo "  Installing helm..."
	@curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

	@# kubeseal
	@echo "  Installing kubeseal..."
	@curl -sL https://github.com/bitnami/sealed-secrets/releases/download/v0.27.1/kubeseal-0.27.1-linux-amd64.tar.gz | tar xz -C /tmp
	@sudo install -m 755 /tmp/kubeseal /usr/local/bin/kubeseal && rm /tmp/kubeseal

	@# argocd cli
	@echo "  Installing argocd cli..."
	@curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
	@sudo install -m 555 /tmp/argocd /usr/local/bin/argocd && rm /tmp/argocd

	@echo "$(GREEN)✅ All CI dependencies installed$(RESET)"
