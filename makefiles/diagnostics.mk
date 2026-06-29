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
	@echo "  diagnose-tls             Diagnose TLS/cert issues"

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

# ============================================
# TLS Diagnostics
# ============================================

.PHONY: diagnose-tls
diagnose-tls: ## Diagnose TLS/cert issues
	@echo "$(YELLOW)🔐 TLS/Cert Diagnostics:$(RESET)"
	@echo ""
	@echo "$(YELLOW)📦 Cert-manager namespace:$(RESET)"
	@kubectl get namespace cert-manager 2>/dev/null || echo "cert-manager namespace not found"
	@echo ""
	@echo "$(YELLOW)📊 Cert-manager pods:$(RESET)"
	@kubectl -n cert-manager get pods 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "$(YELLOW)🌐 Cert-manager services:$(RESET)"
	@kubectl -n cert-manager get svc 2>/dev/null || echo "No services found"
	@echo ""
	@echo "$(YELLOW)📋 ClusterIssuers:$(RESET)"
	@kubectl get clusterissuer 2>/dev/null || echo "No ClusterIssuers found"
	@echo ""
	@echo "$(YELLOW)📋 Certificates:$(RESET)"
	@kubectl get certificate -A 2>/dev/null || echo "No certificates found"
	@echo ""
	@echo "$(YELLOW)📋 Certificate details (describe):$(RESET)"
	@for cert in $$(kubectl get certificate -A -o jsonpath='{.items[*].metadata.namespace}/{.metadata.name}' 2>/dev/null); do \
		ns=$$(echo $$cert | cut -d'/' -f1); \
		name=$$(echo $$cert | cut -d'/' -f2); \
		echo "--- Certificate: $$name (namespace: $$ns) ---"; \
		kubectl -n $$ns describe certificate $$name 2>/dev/null | grep -A10 "Status:"; \
	done
	@echo ""
	@echo "$(YELLOW)🔑 TLS secrets:$(RESET)"
	@kubectl get secret -A 2>/dev/null | grep -E "(tls|cert)" || echo "No TLS secrets found"
	@echo ""
	@echo "$(YELLOW)🌐 Ingress resources:$(RESET)"
	@kubectl get ingress -A 2>/dev/null || echo "No ingress found"
	@echo ""
	@echo "$(YELLOW)✅ Webhook status:$(RESET)"
	@kubectl -n cert-manager get pod --selector=app.kubernetes.io/component=webhook -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null && echo " - Webhook ready" || echo " - Webhook not ready"
	@echo ""
	@echo "$(YELLOW)🔍 Validating webhook:$(RESET)"
	@kubectl get validatingwebhookconfigurations 2>/dev/null | grep cert-manager || echo "Webhook configuration not found"

.PHONY: cluster-status
cluster-status: cluster-namespaces cluster-pods cluster-deployments cluster-services cluster-crds argocd-applications diagnose-tls
	@echo "✅ Cluster snapshot complete"
