# ============================================
# terraform/infra.mk - Terraform Infrastructure
# ============================================
TF_DIR         ?= $(TERRAFORM_DIR)
TF_ENV         ?= $(ENV)
TF_VAR_FILE    ?= $(TF_DIR)/env/$(TF_ENV).tfvars
TF_ARGS        ?= -var-file=$(TF_VAR_FILE) -auto-approve
TF_PARALLELISM ?= 10

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
	@cd $(TF_DIR) && terraform init

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