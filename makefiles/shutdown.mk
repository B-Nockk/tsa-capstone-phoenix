# ============================================
# shutdown.mk - System-wide Shutdown & Cleanup
# ============================================

.PHONY: help-sys
help-sys:
	@echo "$(CYAN)System Lifecycle:$(RESET)"
	@echo "  sys-shutdown          Shutdown everything (cluster, resources, etc.)"
	@echo "  sys-apps-uninstall    Uninstall all applications"
	@echo "  sys-clean             Full cleanup (shutdown + remove generated files)"
	@echo "  sys-setup             Complete project setup (cluster + tools + argo)"
	@echo "  sys-quick-start       Quick start (cluster + app only)"
	@echo "  sys-fresh-start       Complete fresh start (full cleanup + setup)"

.PHONY: sys-shutdown
sys-shutdown: ## Shutdown everything (cluster, resources, etc.)
	@echo "$(RED)🛑 Shutting down all resources...$(RESET)"
	@$(MAKE) sys-apps-uninstall
	@$(MAKE) argo-uninstall
	@$(MAKE) mon-uninstall
	@$(MAKE) k8s-delete
	@echo "$(GREEN)✅ All resources shutdown$(RESET)"

.PHONY: sys-apps-uninstall
sys-apps-uninstall: ## Uninstall all applications
	@echo "$(YELLOW)📦 Uninstalling applications...$(RESET)"
	@$(MAKE) helm-uninstall
	@$(MAKE) helm-argo-uninstall
	@echo "$(GREEN)✅ Applications uninstalled$(RESET)"

.PHONY: sys-clean
sys-clean: sys-shutdown ## Full cleanup (shutdown + remove generated files)
	@echo "$(YELLOW)🧹 Cleaning up generated files...$(RESET)"
	@rm -rf $(SECRETS_DIR)/ 2>/dev/null || true
	@rm -f kubeconfig-*.yaml 2>/dev/null || true
	@rm -f .terraform-outputs.json 2>/dev/null || true
	@rm -rf $(LOGS_DIR)/ 2>/dev/null || true
	@echo "$(GREEN)✅ Full cleanup complete$(RESET)"
