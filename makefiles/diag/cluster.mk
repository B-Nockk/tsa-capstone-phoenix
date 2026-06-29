# ============================================
# diag/cluster.mk - Cluster Diagnostics
# ============================================
ARGOCD_SERVER_PORT ?= 9090
ARGOCD_NAMESPACE   ?= argocd

.PHONY: help-diag-cluster
help-diag-cluster:
	@echo "$(CYAN)Cluster Diagnostics:$(RESET)"
	@echo "  diag-ns               List all namespaces"
	@echo "  diag-pods             List all pods"
	@echo "  diag-deployments      List all deployments"
	@echo "  diag-services         List all services"
	@echo "  diag-crds             List all CRDs"
	@echo "  diag-argo-apps        List all ArgoCD applications"
	@echo "  diag-cluster-status   Show complete cluster snapshot"

.PHONY: diag-ns
diag-ns:
	@kubectl get ns

.PHONY: diag-pods
diag-pods:
	@kubectl get pods --all-namespaces

.PHONY: diag-deployments
diag-deployments:
	@kubectl get deployments --all-namespaces

.PHONY: diag-services
diag-services:
	@kubectl get svc --all-namespaces

.PHONY: diag-crds
diag-crds:
	@kubectl get crd | grep argoproj.io || echo "No Argo CD CRDs found"

.PHONY: diag-argo-apps
diag-argo-apps: ## List all ArgoCD applications
	@echo "📊 ArgoCD Applications:"
	@kubectl get applications -n $(ARGOCD_NAMESPACE) || echo "No applications defined"

.PHONY: diag-argo-ui_duplicate
diag-argo-ui_duplicate:
	@kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) $(ARGOCD_SERVER_PORT):443

.PHONY: diag-cluster-status
diag-cluster-status: diag-ns diag-pods diag-deployments diag-services diag-crds diag-argo-apps
	@echo "✅ Cluster snapshot complete"