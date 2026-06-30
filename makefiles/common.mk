# ============================================
# common.mk - Common utilities and variables
# ============================================
GREEN  := $(shell tput -Txterm setaf 2 2>/dev/null || echo "")
YELLOW := $(shell tput -Txterm setaf 3 2>/dev/null || echo "")
RED    := $(shell tput -Txterm setaf 1 2>/dev/null || echo "")
BLUE   := $(shell tput -Txterm setaf 4 2>/dev/null || echo "")
CYAN   := $(shell tput -Txterm setaf 6 2>/dev/null || echo "")
RESET  := $(shell tput -Txterm sgr0 2>/dev/null || echo "")

ENV              ?= dev
CLOUD            ?= local
HOST             ?= taskapp.local
NAMESPACE        ?= taskapp
PROJECT_NAME     ?= taskapp
CI               ?= false

ROOT_DIR         := $(shell pwd)
INFRA_DIR        ?= infra
TERRAFORM_DIR    ?= $(INFRA_DIR)/terraform
ANSIBLE_DIR      ?= $(INFRA_DIR)/ansible
MANIFESTS_DIR    ?= manifests
HELM_DIR         ?= helm/taskapp
GITOPS_DIR       ?= gitops
SECRETS_DIR      ?= .secrets
LOGS_DIR         ?= logs

LOCAL_SECRETS    := $(SECRETS_DIR)/$(ENV).env
HELM_VALUES_FILE := $(HELM_DIR)/values-$(ENV).yaml

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
