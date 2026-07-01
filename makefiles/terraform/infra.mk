# ============================================
# terraform/infra.mk - Terraform Infrastructure
# ============================================
TF_DIR         ?= $(TERRAFORM_DIR)
TF_ENV         ?= $(ENV)
TF_VAR_FILE    ?= $(TF_DIR)/env/$(TF_ENV).tfvars
TF_VAR_ARG     := $(shell if [ -f $(TF_VAR_FILE) ]; then echo "-var-file=$(TF_VAR_FILE)"; else echo ""; fi)
TF_ARGS        ?= $(TF_VAR_ARG) -auto-approve
TF_PARALLELISM ?= 10

# Default bucket name uses the project name and AWS account ID (or a random string) to ensure uniqueness
TF_STATE_BUCKET ?= $(PROJECT_NAME)-tfstate-$(ENV)
TF_LOCK_TABLE   ?= terraform-locks
TF_REGION       ?= eu-north-1

.PHONY: help-terraform
help-terraform:
	@echo "$(CYAN)Terraform:$(RESET)"
	@echo "  tf-init               Initialize Terraform"
	@echo "  tf-plan               Plan infrastructure changes"
	@echo "  tf-apply              Apply infrastructure"
	@echo "  tf-destroy            Destroy infrastructure"
	@echo "  tf-output             Show Terraform outputs"
	@echo "  tf-ssh                SSH to control plane"

.PHONY: tf-init
tf-init: ## Initialize Terraform
	@echo "$(YELLOW)🔧 Initializing Terraform (Checking for remote state...)$(RESET)"
	@if [ "$(ENABLE_REMOTE_STATE)" = "true" ]; then \
		echo "$(GREEN)☁️  Using remote S3 backend: $(TF_STATE_BUCKET)$(RESET)"; \
		cd $(TF_DIR) && terraform init \
			-backend-config="bucket=$(TF_STATE_BUCKET)" \
			-backend-config="key=$(ENV)/terraform.tfstate" \
			-backend-config="region=$(TF_REGION)" \
			-backend-config="dynamodb_table=$(TF_LOCK_TABLE)" \
			-backend-config="encrypt=true"; \
	else \
		echo "$(YELLOW)💻 Using local state (Remote state disabled)$(RESET)"; \
		cd $(TF_DIR) && terraform init; \
	fi

.PHONY: tf-plan
tf-plan: ## Plan infrastructure changes
	@cd $(TF_DIR) && terraform plan -parallelism=$(TF_PARALLELISM) $(TF_ARGS)

.PHONY: tf-apply
tf-apply: tf-init ## Apply infrastructure
	@cd $(TF_DIR) && terraform apply -parallelism=$(TF_PARALLELISM) $(TF_ARGS)
	@$(MAKE) tf-output

.PHONY: tf-destroy
tf-destroy: tf-init ## Destroy infrastructure
	@cd $(TF_DIR) && terraform destroy -parallelism=$(TF_PARALLELISM) $(TF_ARGS)

.PHONY: tf-output
tf-output: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output

.PHONY: tf-ssh
tf-ssh: ## SSH to control plane
	@cd $(TF_DIR) && terraform output -raw ssh_command 2>/dev/null | bash || echo "❌ Control plane not found"
