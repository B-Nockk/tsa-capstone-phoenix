# ============================================
# gitops.mk - GitOps with ArgoCD
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
ARGOCD_SERVER_PORT		?= 9090
ARGOCD_NAMESPACE		?= argocd
ARGOCD_VERSION       	?= v2.11.0
ARGOCD_SERVER        	?= localhost:$(ARGOCD_SERVER_PORT)
ARGOCD_INSECURE      	?= true
GITOPS_APP_NAME      	?= taskapp
GITOPS_DIR           	?= gitops
ENV                  	?= dev

# File paths (override if needed)
GITOPS_PROJECT_FILE  	?= $(GITOPS_DIR)/project.yaml
GITOPS_APP_FILE      	?= $(GITOPS_DIR)/application.$(ENV).yaml
GITOPS_TEMPLATE      	?= $(GITOPS_DIR)/application-template.yaml
GITOPS_VALUES_FILE   	?= $(GITOPS_DIR)/values-$(ENV).yaml
GITOPS_RENDERED_FILE 	?= $(GITOPS_DIR)/application.$(ENV).yaml

# ============================================
# Help
# ============================================
.PHONY: help-gitops
help-gitops:
	@echo "$(CYAN)GitOps (ArgoCD):$(RESET)"
	@echo "  argocd-install			Install ArgoCD"
	@echo "  argocd-uninstall		Uninstall ArgoCD"
	@echo "  argocd-portforward		Port-forward ArgoCD UI"
	@echo "  argocd-login			Login to ArgoCD"
	@echo "  argocd-apply			Apply ArgoCD applications"
	@echo "  argocd-sync			Sync ArgoCD applications"
	@echo "  argocd-status			Show ArgoCD status"
	@echo "  argocd-deploy			Apply + Sync applications"

# 	@echo "  argocd-render			Render ArgoCD Application for current env"
# 	@echo "  argocd-deploy			Render + Apply + Sync applications"
# ============================================
# ArgoCD Installation
# ============================================

.PHONY: argocd-install
argocd-install:
	@echo "$(GREEN)🚀 Installing ArgoCD...$(RESET)"
	@kubectl create namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true
	@kubectl apply -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@echo "$(YELLOW)⏳ Waiting for ArgoCD pods...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) wait --for=condition=ready pod --all --timeout=300s 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD installed$(RESET)"
	@echo "$(YELLOW)🔑 ArgoCD admin password:$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Check manually"

.PHONY: argocd-uninstall
argocd-uninstall:
	@echo "$(RED)💥 Uninstalling ArgoCD...$(RESET)"
	@kubectl delete namespace $(ARGOCD_NAMESPACE) 2>/dev/null || true
	@echo "$(GREEN)✅ ArgoCD uninstalled$(RESET)"

.PHONY: argocd-portforward
argocd-portforward:
	@echo "$(YELLOW)🔗 Port-forwarding ArgoCD UI to $(ARGOCD_SERVER)...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443

.PHONY: argocd-login
argocd-login:
	@echo "$(YELLOW)🔐 Logging into ArgoCD...$(RESET)"
	@argocd login $(ARGOCD_SERVER) --insecure=$(ARGOCD_INSECURE) --username admin --password $$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# ============================================
# GitOps Application Sync
# ============================================

# TODO:: Parametize yaml env files
# .PHONY: argocd-render
# argocd-render:
# 	@echo "$(GREEN)📝 Rendering ArgoCD Application for $(ENV)...$(RESET)"
# 	@helm template -f $(GITOPS_VALUES_FILE) -s templates/application.yaml . > $(GITOPS_RENDERED_FILE)
# 	@echo "$(GREEN)✅ Rendered to $(GITOPS_RENDERED_FILE)$(RESET)"

# .PHONY: argocd-apply
# argocd-apply: argocd-render
# 	@kubectl apply -f $(GITOPS_PROJECT_FILE) 2>/dev/null || true
# 	@kubectl apply -f $(GITOPS_RENDERED_FILE)
# 	@echo "$(GREEN)✅ ArgoCD applications applied$(RESET)"

.PHONY: argocd-apply
argocd-apply:
	@echo "$(GREEN)📝 Applying ArgoCD applications...$(RESET)"
	@kubectl apply -f $(GITOPS_PROJECT_FILE) 2>/dev/null || true
	@kubectl apply -f $(GITOPS_APP_FILE)
	@echo "$(GREEN)✅ ArgoCD applications applied$(RESET)"

.PHONY: argocd-sync
argocd-sync:
	@echo "$(YELLOW)🔄 Syncing ArgoCD application...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) patch application $(GITOPS_APP_NAME)-$(ENV) -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting for sync...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) wait --for=condition=healthy application/$(GITOPS_APP_NAME)-$(ENV) --timeout=300s 2>/dev/null || echo "$(YELLOW)⚠️  Check ArgoCD UI for sync status$(RESET)"
	@echo "$(GREEN)✅ Sync initiated$(RESET)"

.PHONY: argocd-status
argocd-status:
	@echo "$(YELLOW)📊 ArgoCD application status:$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) get application $(GITOPS_APP_NAME)-$(ENV) -o wide || echo "No application found"
	@echo ""
	@kubectl -n $(ARGOCD_NAMESPACE) get pods
	@echo ""
	@echo "$(YELLOW)🔗 Access ArgoCD UI: kubectl port-forward -n $(ARGOCD_NAMESPACE) svc/argocd-server $(ARGOCD_SERVER_PORT):443$(RESET)"

.PHONY: argocd-deploy
argocd-deploy: argocd-apply argocd-sync
	@echo "$(GREEN)✅ GitOps deployment complete!$(RESET)"
