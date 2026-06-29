# ============================================
# Cluster & ArgoCD Management
# ============================================
ENV					?= dev
ARGOCD_SERVER_PORT	?= 9090
ARGOCD_NAMESPACE	?= argocd
ARGOCD_SERVER		?= localhost:$(ARGOCD_SERVER_PORT)

# ============================================
# Help
# ============================================
.PHONY: help-diagnostics
help-diagnostics:
	@echo "$(CYAN)Cluster Diagnostics:$(RESET)"
	@echo "  cluster-namespaces       List all namespaces"
	@echo "  cluster-pods             List all pods in all namespaces"
	@echo "  cluster-deployments      List all deployments in all namespaces"
	@echo "  cluster-services         List all services in all namespaces"
	@echo "  cluster-crds             List all CRDs installed (argoproj.io related)"
	@echo "  argocd-applications      List all ArgoCD applications"
	@echo "  argocd-ui                Port-forward ArgoCD UI to https://localhost:$(ARGOCD_SERVER_PORT)"
	@echo "  cluster-status           Show complete cluster snapshot"

.PHONY: cluster-namespaces
cluster-namespaces:
	@echo "📂 Namespaces:"
	@kubectl get ns

.PHONY: cluster-pods
cluster-pods:
	@echo "📦 Pods across all namespaces:"
	@kubectl get pods --all-namespaces

.PHONY: cluster-deployments
cluster-deployments:
	@echo "🚀 Deployments across all namespaces:"
	@kubectl get deployments --all-namespaces

.PHONY: cluster-services
cluster-services:
	@echo "🔌 Services across all namespaces:"
	@kubectl get svc --all-namespaces

.PHONY: cluster-crds
cluster-crds:
	@echo "📑 CRDs installed (argoproj.io related):"
	@kubectl get crd | grep argoproj.io || echo "No Argo CD CRDs found"

argocd-applications:
.PHONY: argocd-applications
	@kubectl get applications -n $(ARGOCD_NAMESPACE) || echo "No applications defined"
	@echo "📊 ArgoCD Applications:"

argocd-ui:
.PHONY: argocd-ui
	@kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) $(ARGOCD_SERVER_PORT):443
	@echo "🌐 Forwarding ArgoCD UI to https://$(ARGOCD_SERVER) ..."

.PHONY: cluster-status
cluster-status: cluster-namespaces cluster-pods cluster-deployments cluster-services cluster-crds argocd-applications
	@echo "✅ Cluster snapshot complete"
