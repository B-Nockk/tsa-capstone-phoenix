# ============================================
# terraform.mk - Terraform Infrastructure
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
TF_DIR          ?= $(TERRAFORM_DIR)
TF_ENV          ?= $(ENV)
TF_VAR_FILE     ?= $(TF_DIR)/env/$(TF_ENV).tfvars
TF_ARGS         ?= -var-file=$(TF_VAR_FILE) -auto-approve
TF_PARALLELISM  ?= 10

# ============================================
# Help
# ============================================
.PHONY: help-raw
help-raw:
	@echo "$(CYAN)Terraform:$(RESET)"
	@echo "  infra-init           Initialize Terraform"
	@echo "  infra-plan           Plan infrastructure changes"
	@echo "  infra-apply          Apply infrastructure"
	@echo "  infra-destroy        Destroy infrastructure"
	@echo "  infra-output         Show Terraform outputs"
	@echo "  infra-ssh            SSH to control plane"
	@echo "  infra-kubeconfig     Get kubeconfig from cloud cluster"

# ============================================
# Terraform Commands
# ============================================

.PHONY: infra-init
infra-init: ## Initialize Terraform
	@echo "$(GREEN)📦 Initializing Terraform...$(RESET)"
	@cd $(TF_DIR) && terraform init
	@echo "$(GREEN)✅ Terraform initialized$(RESET)"

.PHONY: infra-plan
infra-plan: ## Plan infrastructure changes
	@echo "$(YELLOW)📋 Planning infrastructure ($(TF_ENV))...$(RESET)"
	@cd $(TF_DIR) && terraform plan -parallelism=$(TF_PARALLELISM) $(TF_ARGS)
	@echo "$(GREEN)✅ Plan complete$(RESET)"

.PHONY: infra-apply
infra-apply: infra-init ## Apply infrastructure
	@echo "$(GREEN)🏗️  Applying infrastructure ($(TF_ENV))...$(RESET)"
	@cd $(TF_DIR) && terraform apply -parallelism=$(TF_PARALLELISM) $(TF_ARGS)
	@echo "$(GREEN)✅ Infrastructure applied$(RESET)"
	@$(MAKE) infra-output

.PHONY: infra-destroy
infra-destroy: infra-init ## Destroy infrastructure
	@echo "$(RED)💥 Destroying infrastructure ($(TF_ENV))...$(RESET)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TF_DIR) && terraform destroy -parallelism=$(TF_PARALLELISM) $(TF_ARGS); \
		echo "$(GREEN)✅ Infrastructure destroyed$(RESET)"; \
	else \
		echo "$(RED)Aborted$(RESET)"; \
	fi

.PHONY: infra-output
infra-output: ## Show Terraform outputs
	@echo "$(YELLOW)📊 Terraform outputs:$(RESET)"
	@cd $(TF_DIR) && terraform output

.PHONY: infra-ssh
infra-ssh: ## SSH to control plane
	@echo "$(YELLOW)🔑 SSH to control plane:$(RESET)"
	@cd $(TF_DIR) && terraform output -raw ssh_command 2>/dev/null | bash || \
		echo "$(RED)❌ Control plane not found$(RESET)"

.PHONY: infra-kubeconfig
infra-kubeconfig: ## Get kubeconfig from cloud cluster
	@echo "$(YELLOW)🔑 Getting kubeconfig...$(RESET)"
	@cd $(TF_DIR) && terraform output -raw kubeconfig_command 2>/dev/null | bash
	@echo "$(GREEN)✅ Kubeconfig saved$(RESET)"