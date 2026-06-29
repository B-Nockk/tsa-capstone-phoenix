# ============================================
# argo/install.mk - ArgoCD Installation
# ============================================
ARGOCD_NAMESPACE ?= argocd
ARGOCD_VERSION   ?= v2.11.0

.PHONY: help-argo-install
help-argo-install:
	@echo "$(CYAN)ArgoCD Installation:$(RESET)"
	@echo "  argo-install          Install ArgoCD"
	@echo "  argo-uninstall        Uninstall ArgoCD"

.PHONY: argo-install
argo-install: ## Install ArgoCD
	@echo "$(GREEN)🚀 Installing ArgoCD...$(RESET)"
	@kubectl create namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true
	@kubectl apply -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@kubectl -n $(ARGOCD_NAMESPACE) wait --for=condition=ready pod --all --timeout=300s 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD installed$(RESET)"

.PHONY: argo-uninstall
argo-uninstall: ## Uninstall ArgoCD
	@echo "$(RED)💥 Uninstalling ArgoCD...$(RESET)"
	@kubectl delete namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true