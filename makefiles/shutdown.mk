# ============================================
# shutdown.mk - System-wide Shutdown & Cleanup
# ============================================

.PHONY: help-sys-shutdown
help-sys-shutdown:
	@echo "$(CYAN)System Shutdown:$(RESET)"
	@echo "  sys-shutdown          Graceful shutdown (Helm uninstall -> k3d delete)"
	@echo "  sys-apps-uninstall    Uninstall all applications via Helm"
	@echo "  sys-clean             Full cleanup (shutdown + remove generated files)"
	@echo ""
	@echo "$(RED)⚠️  Emergency / Force Commands:$(RESET)"
	@echo "  argo-nuke             Force kill stuck ArgoCD namespace (bypasses finalizers)"
	@echo "  sys-nuke              HARD RESET - Force kill ALL non-system namespaces & cluster"

# ============================================
# Graceful Shutdown Flow
# ============================================

.PHONY: sys-shutdown
sys-shutdown: ## Graceful shutdown (cluster, resources, etc.)
	@echo "$(RED)🛑 Shutting down all resources gracefully...$(RESET)"
	@$(MAKE) sys-apps-uninstall
	@$(MAKE) argo-uninstall
	@$(MAKE) mon-uninstall
	@$(MAKE) k8s-delete
	@echo "$(GREEN)✅ Graceful shutdown complete$(RESET)"
	@echo "$(YELLOW)💡 Tip: If ArgoCD gets stuck, run 'make argo-nuke'$(RESET)"

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
	@rm -f kubeconfig-*.yaml .terraform-outputs.json 2>/dev/null || true
	@rm -rf $(LOGS_DIR)/ 2>/dev/null || true
	@echo "$(GREEN)✅ Full cleanup complete$(RESET)"

# ============================================
# 🚨 EMERGENCY / FORCE COMMANDS 🚨
# ============================================

.PHONY: argo-nuke
argo-nuke: ## Force kill stuck ArgoCD namespace (bypasses finalizers)
	@echo "$(RED)💥 Force nuking ArgoCD namespace '$(ARGOCD_NAMESPACE)'...$(RESET)"
	@# 1. Try to delete the install manifest resources first (best effort)
	@kubectl delete -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
	@# 2. Strip finalizers from the namespace to unblock deletion
	@if kubectl get namespace $(ARGOCD_NAMESPACE) 2>/dev/null; then \
		echo "$(YELLOW)🔧 Stripping finalizers from $(ARGOCD_NAMESPACE)...$(RESET)"; \
		kubectl get namespace $(ARGOCD_NAMESPACE) -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$(ARGOCD_NAMESPACE)/finalize" -f - 2>/dev/null || true; \
		sleep 2; \
	fi
	@# 3. Force delete the namespace
	@kubectl delete namespace $(ARGOCD_NAMESPACE) --grace-period=0 --force 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD namespace nuked$(RESET)"

.PHONY: sys-nuke
sys-nuke: ## HARD RESET - Force kill ALL non-system namespaces and delete cluster
	@echo "$(RED)💥 SYSTEM NUKE - Force killing all non-system namespaces...$(RESET)"
	@echo "$(RED)⚠️  WARNING: This will destroy EVERYTHING in the cluster except system namespaces!$(RESET)"
	@# 1. Force delete all non-system namespaces
	@kubectl get namespaces --no-headers | grep -vE "^(kube-|default)" | awk '{print $$1}' | while read ns; do \
		echo "$(YELLOW)🔧 Nuking namespace: $$ns...$(RESET)"; \
		kubectl get namespace $$ns -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$$ns/finalize" -f - 2>/dev/null || true; \
		kubectl delete namespace $$ns --grace-period=0 --force 2>/dev/null || true; \
	done
	@echo "$(YELLOW)🗑️  Deleting k3d cluster '$(K3D_CLUSTER_NAME)'...$(RESET)"
	@# 2. Delete the k3d cluster
	@k3d cluster delete $(K3D_CLUSTER_NAME) 2>/dev/null || true
	@# 3. Clean up local generated files
	@echo "$(YELLOW)🧹 Cleaning up local generated files...$(RESET)"
	@rm -rf $(SECRETS_DIR)/ 2>/dev/null || true
	@rm -f kubeconfig-*.yaml .terraform-outputs.json 2>/dev/null || true
	@rm -rf $(LOGS_DIR)/ 2>/dev/null || true
	@echo "$(GREEN)✅ System completely nuked and reset$(RESET)"
