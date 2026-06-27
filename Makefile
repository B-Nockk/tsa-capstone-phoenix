# ============================================
# TSA Capstone Phoenix - Makefile
# ============================================
# Usage: make <target>
#
# Targets:
#   help                - Show this help
#   init                - Initialize Terraform
#   plan                - Plan Terraform infrastructure
#   apply               - Apply Terraform infrastructure
#   destroy             - Destroy Terraform infrastructure
#   output              - Show Terraform outputs
#   ssh                 - SSH to control plane
#   kubeconfig          - Get kubeconfig from control plane
#   clean               - Clean up Terraform state files
#   setup               - Full setup (init + plan + apply)
# ============================================

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

# Default target
.PHONY: help
help:
	@echo "${GREEN}TSA Capstone Phoenix - Makefile${RESET}"
	@echo ""
	@echo "${YELLOW}Usage:${RESET} make <target>"
	@echo ""
	@echo "${YELLOW}Infrastructure Targets:${RESET}"
	@echo "  ${GREEN}init${RESET}        - Initialize Terraform"
	@echo "  ${GREEN}plan${RESET}        - Plan Terraform infrastructure"
	@echo "  ${GREEN}apply${RESET}       - Apply Terraform infrastructure"
	@echo "  ${GREEN}destroy${RESET}     - Destroy Terraform infrastructure"
	@echo "  ${GREEN}output${RESET}      - Show Terraform outputs"
	@echo "  ${GREEN}ssh${RESET}         - SSH to control plane"
	@echo "  ${GREEN}kubeconfig${RESET}  - Get kubeconfig from control plane"
	@echo "  ${GREEN}clean${RESET}       - Clean up Terraform state files"
	@echo "  ${GREEN}setup${RESET}       - Full setup (init + plan + apply)"
	@echo ""
	@echo "${YELLOW}Environment:${RESET}"
	@echo "  TF_ENV          - Environment to use (dev/prod), default: dev"
	@echo "  TF_VAR_FILE     - Variable file to use, default: env/dev.tfvars"
	@echo ""
	@echo "${YELLOW}Examples:${RESET}"
	@echo "  make init TF_ENV=dev"
	@echo "  make apply TF_ENV=prod"
	@echo "  make setup TF_ENV=dev"

# ============================================
# Environment Configuration
# ============================================

TF_ENV ?= dev
TF_DIR := infra/terraform
TF_VAR_FILE := $(abspath $(TF_DIR)/env/$(TF_ENV).tfvars)
TF_ARGS := -var-file=$(TF_VAR_FILE)

# Check if variable file exists
check-env:
	@if [ ! -f $(TF_VAR_FILE) ]; then \
		echo "$(RED)Error: $(TF_VAR_FILE) not found!$(RESET)"; \
		echo "Available files:"; \
		ls -la $(TF_DIR)/env/ 2>/dev/null || echo "  No files found"; \
		exit 1; \
	fi

# ============================================
# Terraform Commands
# ============================================

.PHONY: init
init: check-env
	@echo "$(GREEN)Initializing Terraform...$(RESET)"
	@cd $(TF_DIR) && terraform init
	@echo "$(GREEN)✓ Initialized!$(RESET)"

.PHONY: plan
plan: check-env
	@echo "$(YELLOW)Planning infrastructure for $(TF_ENV)...$(RESET)"
	@cd $(TF_DIR) && terraform plan $(TF_ARGS)
	@echo "$(GREEN)✓ Plan complete!$(RESET)"

.PHONY: apply
apply: check-env
	@echo "$(YELLOW)Applying infrastructure for $(TF_ENV)...$(RESET)"
	@cd $(TF_DIR) && terraform apply $(TF_ARGS) -auto-approve
	@echo "$(GREEN)✓ Infrastructure applied!$(RESET)"
	@make output

.PHONY: destroy
destroy: check-env
	@echo "$(RED)WARNING: This will destroy all infrastructure for $(TF_ENV)!$(RESET)"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TF_DIR) && terraform destroy $(TF_ARGS) -auto-approve; \
		echo "$(GREEN)✓ Infrastructure destroyed!$(RESET)"; \
	else \
		echo "$(RED)Aborted.$(RESET)"; \
	fi

.PHONY: output
output: check-env
	@echo "$(YELLOW)Terraform Outputs:$(RESET)"
	@cd $(TF_DIR) && terraform output

.PHONY: ssh
ssh: check-env
	@echo "$(YELLOW)SSH to control plane...$(RESET)"
	@cd $(TF_DIR) && \
	ssh -i $$(terraform output -raw ssh_private_key_path 2>/dev/null || echo "~/.ssh/tsa-capstone/tsa-capstone-key") \
	ubuntu@$$(terraform output -raw control_plane_public_ips 2>/dev/null || echo "NO_IP")

.PHONY: kubeconfig
kubeconfig: check-env
	@echo "$(YELLOW)Getting kubeconfig...$(RESET)"
	@cd $(TF_DIR) && \
	IP=$$(terraform output -raw control_plane_public_ips 2>/dev/null); \
	KEY=$$(terraform output -raw ssh_private_key_path 2>/dev/null || echo "~/.ssh/tsa-capstone/tsa-capstone-key"); \
	if [ -z "$$IP" ]; then \
		echo "$(RED)No control plane IP found. Run 'make apply' first.$(RESET)"; \
		exit 1; \
	fi; \
	scp -i $$KEY -o StrictHostKeyChecking=no ubuntu@$$IP:/etc/rancher/k3s/k3s.yaml ./kubeconfig-$(TF_ENV).yaml && \
	sed -i "s/127.0.0.1/$$IP/g" ./kubeconfig-$(TF_ENV).yaml && \
	echo "$(GREEN)✓ Kubeconfig saved to ./kubeconfig-$(TF_ENV).yaml$(RESET)" && \
	echo "export KUBECONFIG=./kubeconfig-$(TF_ENV).yaml"

.PHONY: clean
clean:
	@echo "$(YELLOW)Cleaning up Terraform state...$(RESET)"
	@cd $(TF_DIR) && rm -rf .terraform/ terraform.tfstate* .terraform.lock.hcl tfplan
	@rm -f kubeconfig-*.yaml
	@echo "$(GREEN)✓ Cleaned up!$(RESET)"

# ============================================
# Setup Targets
# ============================================

.PHONY: setup
setup: init plan apply
	@echo "$(GREEN)✓ Setup complete!$(RESET)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Get kubeconfig:    make kubeconfig"
	@echo "  2. SSH to control:    make ssh"
	@echo "  3. Deploy manifests:  cd manifests && kubectl apply -f ."
	@echo "  4. Install ArgoCD:    cd gitops && make install"

# ============================================
# Quick Commands (for common tasks)
# ============================================

.PHONY: status
status:
	@echo "$(YELLOW)Checking cluster status...$(RESET)"
	@kubectl get nodes
	@kubectl get pods --all-namespaces

.PHONY: logs
logs:
	@echo "$(YELLOW)Showing pod logs...$(RESET)"
	@kubectl logs -f --all-containers --namespace=taskapp

.PHONY: deploy
deploy:
	@echo "$(GREEN)Deploying application...$(RESET)"
	@kubectl apply -f manifests/

.PHONY: delete-app
delete-app:
	@echo "$(RED)Deleting application...$(RESET)"
	@kubectl delete -f manifests/ || true

# ============================================
# Check dependencies
# ============================================

.PHONY: check-deps
check-deps:
	@echo "$(YELLOW)Checking dependencies...$(RESET)"
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)❌ terraform not found$(RESET)"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "$(RED)❌ aws CLI not found$(RESET)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)❌ kubectl not found$(RESET)"; exit 1; }
	@command -v ansible >/dev/null 2>&1 || { echo "$(RED)❌ ansible not found$(RESET)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies found!$(RESET)"

# ============================================
# Helpful info
# ============================================

.PHONY: info
info: output
	@echo ""
	@echo "$(YELLOW)SSH Key:$(RESET)"
	@cd $(TF_DIR) && terraform output ssh_private_key_path 2>/dev/null || echo "Not found"
	@echo "$(YELLOW)SSH Command:$(RESET)"
	@cd $(TF_DIR) && terraform output ssh_command 2>/dev/null || echo "Not found"
	@echo "$(YELLOW)Ansible Inventory:$(RESET)"
	@cd $(TF_DIR) && terraform output ansible_inventory_path 2>/dev/null || echo "Not found"