# ============================================
# helm/argo.mk - ArgoCD Ingress via Helm
# ============================================
ARGOCD_HELM_DIR   ?= helm/argocd
ARGOCD_RELEASE_NAME ?= argocd-ingress

.PHONY: help-helm-argo
help-helm-argo:
	@echo "$(CYAN)Helm ArgoCD Ingress:$(RESET)"
	@echo "  helm-argo-deploy      Deploy/upgrade ArgoCD ingress via Helm"
	@echo "  helm-argo-uninstall   Uninstall ArgoCD ingress"
	@echo "  helm-argo-status      Show ArgoCD ingress status"

.PHONY: helm-argo-deploy
helm-argo-deploy: ## Deploy/upgrade ArgoCD ingress via Helm
	@helm upgrade --install $(ARGOCD_RELEASE_NAME) $(ARGOCD_HELM_DIR) --namespace $(ARGOCD_NAMESPACE) --create-namespace

.PHONY: helm-argo-uninstall
helm-argo-uninstall: ## Uninstall ArgoCD ingress
	@helm uninstall $(ARGOCD_RELEASE_NAME) -n $(ARGOCD_NAMESPACE) || true

.PHONY: helm-argo-status
helm-argo-status: ## Show ArgoCD ingress status
	@kubectl -n $(ARGOCD_NAMESPACE) get ingress