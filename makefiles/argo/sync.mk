# ============================================
# argo/sync.mk - ArgoCD GitOps Sync
# ============================================
GITOPS_APP_NAME       ?= taskapp
GITOPS_PROJECT_FILE   ?= $(GITOPS_DIR)/project.yaml
GITOPS_APP_FILE       ?= $(GITOPS_DIR)/application.$(ENV).yaml

.PHONY: help-argo-sync
help-argo-sync:
	@echo "$(CYAN)ArgoCD Sync:$(RESET)"
	@echo "  argo-apply            Apply ArgoCD applications"
	@echo "  argo-sync             Sync ArgoCD applications"
	@echo "  argo-status           Show ArgoCD status"
	@echo "  argo-deploy           Apply + Sync applications"

.PHONY: argo-apply
argo-apply: ## Apply ArgoCD applications
	@kubectl apply -f $(GITOPS_PROJECT_FILE) 2>/dev/null || true
	@kubectl apply -f $(GITOPS_APP_FILE)

.PHONY: argo-sync
argo-sync: ## Sync ArgoCD application
	@kubectl -n $(ARGOCD_NAMESPACE) patch application $(GITOPS_APP_NAME)-$(ENV) -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' 2>/dev/null || true
	@kubectl -n $(ARGOCD_NAMESPACE) wait --for=condition=healthy application/$(GITOPS_APP_NAME)-$(ENV) --timeout=300s 2>/dev/null || true

.PHONY: argo-status
argo-status: ## Show ArgoCD application status
	@kubectl -n $(ARGOCD_NAMESPACE) get application $(GITOPS_APP_NAME)-$(ENV) -o wide || echo "No application found"

.PHONY: argo-deploy
argo-deploy: argo-apply argo-sync ## Apply + Sync applications
	@echo "$(GREEN)✅ GitOps deployment complete!$(RESET)"