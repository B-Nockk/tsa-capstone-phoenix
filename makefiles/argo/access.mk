# ============================================
# argo/access.mk - ArgoCD Access & Port-forwarding
# ============================================
ARGOCD_SERVER_PORT ?= 9090
ARGOCD_SERVER      ?= localhost:$(ARGOCD_SERVER_PORT)
ARGOCD_INSECURE    ?= true

.PHONY: help-argo-access
help-argo-access:
	@echo "$(CYAN)ArgoCD Access:$(RESET)"
	@echo "  argo-portforward      Port-forward ArgoCD UI"
	@echo "  argo-login            Login to ArgoCD CLI"
	@echo "  argo-url              Show ArgoCD access URL"
	@echo "  argo-password         Get ArgoCD admin password"

.PHONY: argo-portforward
argo-portforward: ## Port-forward ArgoCD UI
	@echo "$(YELLOW)🔗 Forwarding to $(ARGOCD_SERVER)...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443

.PHONY: argo-portforward_duplicate
argo-portforward_duplicate:
	@kubectl -n $(ARGOCD_NAMESPACE) port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443

.PHONY: argo-login
argo-login: ## Login to ArgoCD via CLI
	@echo "$(YELLOW)🔐 Logging into ArgoCD...$(RESET)"
	@kubectl -n $(ARGOCD_NAMESPACE) port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443 &>/dev/null &
	@sleep 2
	@argocd login $(ARGOCD_SERVER) --insecure=$(ARGOCD_INSECURE) --username admin --password $$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

.PHONY: argo-login_duplicate
argo-login_duplicate:
	@argocd login $(ARGOCD_SERVER) --insecure=$(ARGOCD_INSECURE) --username admin --password $$(kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

.PHONY: argo-url
argo-url: ## Show ArgoCD access URL
	@echo "$(GREEN)https://$(ARGOCD_SERVER)$(RESET)"

.PHONY: argo-password
argo-password: ## Get ArgoCD admin password
	@kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "Password not found"