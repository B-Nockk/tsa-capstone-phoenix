# ============================================
# startup.mk - System-wide Startup & Setup
# ============================================

# Toggle: set to 'false' for CI/CD or production to keep ArgoCD's auto-generated password
ARGOCD_RESET_PASSWORD ?= true
ARGOCD_DEFAULT_PASS   ?= ArgoCD123

.PHONY: help-sys-startup
help-sys-startup:
	@echo "$(CYAN)System Startup:$(RESET)"
	@echo "  sys-setup             Complete project setup (cluster + tools + argo)"
	@echo "  sys-quick-start       Quick start (cluster + app only)"
	@echo "  sys-fresh-start       Complete fresh start (full cleanup + setup)"
	@echo ""
	@echo "$(YELLOW)  Tip: make sys-setup ARGOCD_RESET_PASSWORD=false  (CI/CD mode)$(RESET)"


.PHONY: sys-setup
sys-setup: setup ## Complete project setup (uses common setup for dirs first)
	@echo "$(GREEN)🔧 Setting up full project stack...$(RESET)"
	@$(MAKE) check-tools
	@# 1. Create the cluster first
	@$(MAKE) k8s-create
	@# 2. Install core infrastructure
	@$(MAKE) k8s-ingress-install
	@$(MAKE) k8s-cert-install
	@$(MAKE) k8s-issuer-apply-retry
	@# 3. Install cluster-dependent tools
	@$(MAKE) sec-install-controller
	@$(MAKE) sec-generate ENV=$(ENV) AUTO_INJECT=true
	@# 4. Install ArgoCD
	@$(MAKE) argo-install
	@# 5. Conditionally reset ArgoCD password
	@if [ "$(ARGOCD_RESET_PASSWORD)" = "true" ]; then \
		echo "$(YELLOW)🔑 Resetting ArgoCD password to '$(ARGOCD_DEFAULT_PASS)' (local dev mode)...$(RESET)"; \
		$(MAKE) argo-reset PASSWORD=$(ARGOCD_DEFAULT_PASS); \
	else \
		echo "$(GREEN)🔐 Keeping ArgoCD auto-generated password (CI/CD mode)$(RESET)"; \
		echo "$(YELLOW)   Fetch it with: make argo-password$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Setup complete!$(RESET)"

.PHONY: sys-quick-start
sys-quick-start: ## Quick start (cluster + app only)
	@echo "$(GREEN)🚀 Quick starting...$(RESET)"
	@$(MAKE) k8s-create
	@$(MAKE) k8s-ingress-install
	@$(MAKE) helm-deploy ENV=$(ENV)
	@$(MAKE) helm-test-app
	@echo "$(GREEN)✅ Quick start complete!$(RESET)"
	@echo "$(YELLOW)📍 Access: http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)$(RESET)"

.PHONY: sys-fresh-start
sys-fresh-start: ## Complete fresh start (full cleanup + setup)
	@echo "$(GREEN)🚀 Starting fresh...$(RESET)"
	@$(MAKE) sys-clean
	@$(MAKE) sys-setup ARGOCD_RESET_PASSWORD=$(ARGOCD_RESET_PASSWORD)
	@echo "$(GREEN)✅ Fresh start complete!$(RESET)"
	@echo "$(YELLOW)📍 Next steps:$(RESET)"
	@echo "  1. Deploy app: make helm-deploy ENV=$(ENV)"
	@echo "  2. Check status: make helm-status"
	@echo "  3. Access ArgoCD: make argo-portforward"
