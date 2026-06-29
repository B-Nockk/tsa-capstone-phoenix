# ============================================
# gitops.mk - GitOps with ArgoCD
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
ARGOCD_NAMESPACE    ?= argocd
ARGOCD_VERSION      ?= v2.11.0
ARGOCD_SERVER       ?= localhost:8080
ARGOCD_INSECURE     ?= true
GITOPS_APP_NAME     ?= taskapp

# ============================================
# Help
# ============================================
.PHONY: help-gitops
help-gitops:
	@echo "$(CYAN)GitOps (ArgoCD):$(RESET)"
	@echo "  argocd-install       Install ArgoCD"
	@echo "  argocd-uninstall     Uninstall ArgoCD"
	@echo "  argocd-portforward   Port-forward ArgoCD UI"
	@echo "  argocd-login         Login to ArgoCD"
	@echo "  argocd-apply         Apply ArgoCD applications"
	@echo "  argocd-sync          Sync ArgoCD applications"
	@echo "  argocd-status        Show ArgoCD status"

# ============================================
# ArgoCD Installation
# ============================================

.PHONY: argocd-install
argocd-install: ## Install ArgoCD
	@echo "$(GREEN)🚀 Installing ArgoCD...$(RESET)"
	@kubectl create namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true
	@kubectl apply -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@echo "$(YELLOW)⏳ Waiting for ArgoCD pods...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) wait --for=condition=ready pod --all --timeout=300s 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD installed$(RESET)"
	@echo "$(YELLOW)🔑 ArgoCD admin password:$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Check manually"

.PHONY: argocd-uninstall
argocd-uninstall: ## Uninstall ArgoCD
	@echo "$(RED)💥 Uninstalling ArgoCD...$(RESET)"
	@kubectl delete namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD uninstalled$(RESET)"

.PHONY: argocd-portforward
argocd-portforward: ## Port-forward ArgoCD UI
	@echo "$(YELLOW)🔗 Port-forwarding ArgoCD UI to $(ARGOCD_SERVER)...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) port-forward svc/argocd-server $(ARGOCD_SERVER) 2>/dev/null

.PHONY: argocd-login
argocd-login: ## Login to ArgoCD
	@echo "$(YELLOW)🔐 Logging into ArgoCD...$(RESET)"
	@argocd login $(ARGOCD_SERVER) --insecure=$(ARGOCD_INSECURE) --username admin --password $$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# ============================================
# ArgoCD Application Management
# ============================================

.PHONY: argocd-apply
argocd-apply: ## Apply ArgoCD applications
	@echo "$(GREEN)📝 Applying ArgoCD applications...$(RESET)"
	@kubectl apply -f $(GITOPS_DIR)/
	@echo "$(GREEN)✅ Applications applied$(RESET)"

.PHONY: argocd-sync
argocd-sync: ## Sync ArgoCD applications
	@echo "$(YELLOW)🔄 Syncing ArgoCD applications...$(RESET)"
	@argocd app sync $(GITOPS_APP_NAME) 2>/dev/null || \
		kubectl -n $(ARGOCD_NAMESPACE) get application $(GITOPS_APP_NAME) -o yaml | \
		grep -q "syncStatus: " || \
		echo "$(YELLOW)⚠️  Application not found. Run 'make argocd-apply' first.$(RESET)"

.PHONY: argocd-status
argocd-status: ## Show ArgoCD status
	@echo "$(YELLOW)📊 ArgoCD status:$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) get application
	@echo ""
	@kubectl -n $(ARGOCD_NAMESPACE) get pods
