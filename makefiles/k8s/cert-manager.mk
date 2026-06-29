# ============================================
# k8s/cert-manager.mk - Cert-Manager
# ============================================
CERT_MANAGER_VERSION ?= 1.20.3

.PHONY: help-k8s-cert
help-k8s-cert:
	@echo "$(CYAN)Kubernetes Cert-Manager:$(RESET)"
	@echo "  k8s-cert-install      Install cert-manager"
	@echo "  k8s-cert-uninstall    Uninstall cert-manager"
	@echo "  k8s-cert-status       Show cert-manager status"

.PHONY: k8s-cert-install
k8s-cert-install: ## Install cert-manager
	@echo "$(GREEN)🔐 Installing cert-manager...$(RESET)"
	@helm repo add jetstack https://charts.jetstack.io --force-update 2>/dev/null
	@helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version $(CERT_MANAGER_VERSION) --set crds.enabled=true --wait --timeout 180s 2>/dev/null || true
	@kubectl -n cert-manager wait --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s 2>/dev/null || true

.PHONY: k8s-cert-uninstall
k8s-cert-uninstall: ## Uninstall cert-manager
	@helm uninstall cert-manager -n cert-manager || true

.PHONY: k8s-cert-status
k8s-cert-status: ## Show cert-manager status
	@kubectl -n cert-manager get pods