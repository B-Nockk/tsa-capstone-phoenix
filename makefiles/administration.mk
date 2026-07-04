# ==============================================================================
# administration.mk - GitHub Actions Pipeline Automation
# ==============================================================================

# Automatically grab the active git branch
GH_BRANCH ?= $(shell git branch --show-current)

# Default pipeline timeout (can be overridden: make gh-deploy-full TIMEOUT=20)
TIMEOUT ?= 45

.PHONY: help-admin
help-admin:
	@echo "$(CYAN)Pipeline Administration (GitHub Actions):$(RESET)"
	@echo "  gh-deploy-full      Run complete pipeline (Terraform -> Ansible -> ArgoCD)"
	@echo "  gh-deploy-duckdns   Run complete pipeline with duckdns"
	@echo "  gh-deploy-infra     Run ONLY Terraform provisioning"
	@echo "  gh-deploy-k8s       Run ONLY Ansible K3s installation"
	@echo "  gh-deploy-argo      Run ONLY ArgoCD application sync"
	@echo "  gh-deploy-custom    Run with custom flags (e.g., TF=true ANS=false ARGO=true)"
	@echo "  gh-destroy          Run destroy pipeline"
	@echo "  gh-status           View the status of recent workflow runs"

# Toggles for the custom run (Default to false for safety)
TF   ?= false
ANS  ?= false
ARGO ?= false

# ==============================================================================
# Execution Targets
# ==============================================================================

.PHONY: gh-deploy-full
gh-deploy-full: ## Run the complete pipeline
	@echo "$(GREEN)🚀 Triggering FULL deployment pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=true \
		-f run_ansible=true \
		-f deploy_argo=true

.PHONY: gh-deploy-duckdns
gh-deploy-duckdns: ## Run the complete pipeline
	@echo "$(GREEN)🚀 Triggering FULL deployment pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=true \
		-f run_ansible=true \
		-f deploy_argo=true \
		-f use_duckdns=true

.PHONY: gh-deploy-infra
gh-deploy-infra: ## Run only Terraform
	@echo "$(YELLOW)🏗️ Triggering INFRASTRUCTURE ONLY pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=true \
		-f run_ansible=false \
		-f deploy_argo=false

.PHONY: gh-deploy-k8s
gh-deploy-k8s: ## Run only Ansible
	@echo "$(BLUE)☸️ Triggering KUBERNETES ONLY pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=false \
		-f run_ansible=true \
		-f deploy_argo=false

.PHONY: gh-deploy-argo
gh-deploy-argo: ## Run only ArgoCD
	@echo "$(MAGENTA)🐙 Triggering ARGOCD ONLY pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=false \
		-f run_ansible=false \
		-f deploy_argo=true

.PHONY: gh-deploy-custom
gh-deploy-custom: ## Run custom pipeline
	@echo "$(CYAN)🎛️ Triggering CUSTOM pipeline on branch: $(GH_BRANCH) (TF=$(TF), ANS=$(ANS), ARGO=$(ARGO))$(RESET)"
	@gh workflow run deploy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f timeout_minutes=$(TIMEOUT) \
		-f run_terraform=$(TF) \
		-f run_ansible=$(ANS) \
		-f deploy_argo=$(ARGO)

.PHONY: gh-destroy
gh-destroy: ## Trigger the destroy pipeline
	@echo "$(RED)🔥 Triggering DESTROY pipeline on branch: $(GH_BRANCH)$(RESET)"
	@gh workflow run destroy.yaml --ref $(GH_BRANCH) \
		-f environment=$(ENV) \
		-f safety_catch=DESTROY
	@echo "$(YELLOW)Note: Verify that your destroy.yaml workflow is configured to accept the environment input.$(RESET)"

.PHONY: gh-status
gh-status: ## Watch the pipeline status
	@echo "$(CYAN)Recent Workflow Runs:$(RESET)"
	@gh run list --workflow=deploy.yaml --limit 5
	@echo "\n$(YELLOW)Tip: Run 'gh run watch <RUN_ID>' to see live logs in your terminal.$(RESET)"
