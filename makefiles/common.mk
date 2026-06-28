# ============================================
# common.mk - Common utilities and variables
# ============================================

# ============================================
# Colors (overridable via env)
# ============================================
GREEN  := $(shell tput -Txterm setaf 2 2>/dev/null || echo "")
YELLOW := $(shell tput -Txterm setaf 3 2>/dev/null || echo "")
RED    := $(shell tput -Txterm setaf 1 2>/dev/null || echo "")
BLUE   := $(shell tput -Txterm setaf 4 2>/dev/null || echo "")
CYAN   := $(shell tput -Txterm setaf 6 2>/dev/null || echo "")
RESET  := $(shell tput -Txterm sgr0 2>/dev/null || echo "")

# ============================================
# Core Variables (overridable via env)
# ============================================
ENV              ?= dev
CLOUD            ?= local
HOST             ?= taskapp.local
NAMESPACE        ?= taskapp
PROJECT_NAME     ?= taskapp
CI               ?= false

# ============================================
# Directory Variables (overridable via env)
# ============================================
ROOT_DIR         := $(shell pwd)
INFRA_DIR        ?= infra
TERRAFORM_DIR    ?= $(INFRA_DIR)/terraform
ANSIBLE_DIR      ?= $(INFRA_DIR)/ansible
MANIFESTS_DIR    ?= manifests
HELM_DIR         ?= helm/taskapp
GITOPS_DIR       ?= gitops
SECRETS_DIR      ?= .secrets
LOGS_DIR         ?= logs

# ============================================
# Derived Variables
# ============================================
LOCAL_SECRETS    := $(SECRETS_DIR)/$(ENV).env
HELM_VALUES_FILE := $(HELM_DIR)/values-$(ENV).yaml

# ============================================
# Utility Functions
# ============================================

# Check if a command exists
define check_cmd
	@command -v $(1) >/dev/null 2>&1 || { echo "$(RED)❌ $(1) not found$(RESET)"; exit 1; }
endef

# Wait for a resource
define wait_for
	@echo "$(YELLOW)⏳ Waiting for $(1)...$(RESET)"
	@kubectl wait --for=condition=ready $(2) --all --timeout=$(3) 2>/dev/null || true
endef

# Generate random password
define gen_password
	@openssl rand -base64 32 | tr -d '\n'
endef

# ============================================
# Help System
# ============================================

# Help will be collected from all makefiles
# Each file should define a help-raw target

.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)TaskApp Makefile Help$(RESET)"
	@echo ""
	@echo "$(YELLOW)Usage: make [target] [VARIABLE=value]$(RESET)"
	@echo ""
	@echo "$(CYAN)Environment Variables:$(RESET)"
	@echo "  ENV              Environment (dev/prod) [default: dev]"
	@echo "  CLOUD            Cloud provider (aws/local) [default: local]"
	@echo "  NAMESPACE        Kubernetes namespace [default: taskapp]"
	@echo "  HOST             Hostname for ingress [default: taskapp.local]"
	@echo ""
	@$(MAKE) -f makefiles/common.mk help-raw
	@$(MAKE) -f makefiles/terraform.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/ansible.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/kubernetes.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/helm.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/gitops.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/monitoring.mk help-raw 2>/dev/null || true
	@$(MAKE) -f makefiles/ci-cd.mk help-raw 2>/dev/null || true
	@echo ""
	@echo "$(YELLOW)Quick Start:$(RESET)"
	@echo "  make local-up      Full local deployment"
	@echo "  make cloud-up      Full cloud deployment"
	@echo "  make local-down    Destroy local environment"
	@echo "  make cloud-down    Destroy cloud environment"

.PHONY: help-raw
help-raw:
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
	@echo "$(GREEN)✅ All tools installed$(RESET)"

.PHONY: version
version: ## Show version information
	@echo "Project: $(PROJECT_NAME)"
	@echo "Environment: $(ENV)"
	@echo "Cloud: $(CLOUD)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Host: $(HOST)"

.PHONY: setup
setup: ## Complete project setup (create directories)
	@echo "$(GREEN)Setting up project structure...$(RESET)"
	@mkdir -p $(SECRETS_DIR) $(LOGS_DIR)
	@echo "$(GREEN)✓ Project structure created$(RESET)"