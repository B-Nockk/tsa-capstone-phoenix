# ============================================
# startup.mk - System-wide Startup & Setup
# ============================================

.PHONY: sys-setup
sys-setup: setup ## Complete project setup (uses common setup for dirs first)
	@echo "$(GREEN)🔧 Setting up full project stack...$(RESET)"
	@$(MAKE) check-tools
	@$(MAKE) sec-install-controller
	@$(MAKE) sec-generate ENV=$(ENV)
	@$(MAKE) k8s-create
	@$(MAKE) k8s-ingress-install
	@$(MAKE) k8s-cert-install
	@$(MAKE) k8s-issuer-apply-retry
	@$(MAKE) argo-install
	@$(MAKE) argo-reset PASSWORD=ArgoCD123
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
	@$(MAKE) sys-setup
	@echo "$(GREEN)✅ Fresh start complete!$(RESET)"
	@echo "$(YELLOW)📍 Next steps:$(RESET)"
	@echo "  1. Deploy app: make helm-deploy ENV=$(ENV)"
	@echo "  2. Check status: make helm-status"
	@echo "  3. Access ArgoCD: make argo-ui"
