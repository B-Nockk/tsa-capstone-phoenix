# ============================================
# terraform/infra.mk - Terraform Infrastructure
# ============================================
TF_DIR         ?= $(TERRAFORM_DIR)
TF_ENV         ?= $(ENV)
TF_VAR_FILE    ?= $(TF_DIR)/env/$(TF_ENV).tfvars
TF_VAR_ARG     := $(shell if [ -f $(TF_VAR_FILE) ]; then echo "-var-file=$(TF_VAR_FILE)"; else echo ""; fi)
TF_ARGS        ?= $(TF_VAR_ARG) -auto-approve
TF_PARALLELISM ?= 10

# Fetch the Account ID dynamically. If it fails (e.g. running locally without creds), fallback to "local"
# TODO:: highlight in docs that the .gh_vars file content should be added to env if one wants to use controlled config for backend in local env
AWS_ACCOUNT_ID  ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "local")
TF_STATE_BUCKET ?= $(TF_VAR_project_name)-tfstate-$(AWS_ACCOUNT_ID)-$(ENV)
TF_LOCK_TABLE   ?= $(TF_VAR_project_name)-tfstate-locks-$(ENV)
TF_REGION       ?= $(TF_VAR_aws_region)

.PHONY: help-terraform
help-terraform:
	@echo "$(CYAN)Terraform:$(RESET)"
	@echo "  tf-init               Initialize Terraform"
	@echo "  tf-plan               Plan infrastructure changes"
	@echo "  tf-apply              Apply infrastructure"
	@echo "  tf-destroy            Destroy infrastructure"
	@echo "  tf-output             Show Terraform outputs"
	@echo "  tf-ssh                SSH to control plane"

.PHONY: tf-backend-setup
tf-backend-setup: ## Idempotently verify or create S3 bucket and DynamoDB table
	@echo "$(YELLOW)☁️  Verifying Terraform backend infrastructure...$(RESET)"
	@if [ "$(ENABLE_REMOTE_STATE)" = "true" ]; then \
		echo "  Target S3 Bucket: $(TF_STATE_BUCKET)"; \
		if ! aws s3api head-bucket --bucket $(TF_STATE_BUCKET) 2>/dev/null; then \
			echo "$(YELLOW)  Bucket does not exist or access denied. Attempting to create...$(RESET)"; \
			if ! aws s3 mb s3://$(TF_STATE_BUCKET) --region $(TF_REGION); then \
				echo "$(RED)❌ Failed to create bucket '$(TF_STATE_BUCKET)'.$(RESET)"; \
				echo "$(RED)   If you provided a custom name, it may be taken globally by another AWS user.$(RESET)"; \
				echo "$(RED)   Action: Provide a truly unique name, or leave TF_STATE_BUCKET blank to auto-generate.$(RESET)"; \
				exit 1; \
			fi; \
			echo "$(GREEN)  ✅ Bucket successfully created.$(RESET)"; \
		else \
			echo "$(GREEN)  ✅ Bucket exists and is accessible.$(RESET)"; \
		fi; \
		echo "  Target DynamoDB Table: $(TF_LOCK_TABLE)"; \
		if ! aws dynamodb describe-table --table-name $(TF_LOCK_TABLE) --region $(TF_REGION) 2>/dev/null; then \
			echo "$(YELLOW)  Table does not exist. Creating...$(RESET)"; \
			aws dynamodb create-table \
				--table-name $(TF_LOCK_TABLE) \
				--attribute-definitions AttributeName=LockID,AttributeType=S \
				--key-schema AttributeName=LockID,KeyType=HASH \
				--billing-mode PAY_PER_REQUEST \
				--region $(TF_REGION) > /dev/null; \
			aws dynamodb wait table-exists --table-name $(TF_LOCK_TABLE) --region $(TF_REGION); \
			echo "$(GREEN)  ✅ Table successfully created.$(RESET)"; \
		else \
			echo "$(GREEN)  ✅ Table exists and is accessible.$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)  Remote state is disabled. Skipping backend setup.$(RESET)"; \
	fi

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
