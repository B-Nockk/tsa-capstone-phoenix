# ============================================
# argo/management.mk - ArgoCD Management
# ============================================
.PHONY: help-argo-management
help-argo-management:
	@echo "$(CYAN)ArgoCD Management:$(RESET)"
	@echo "  argo-reset            Reset ArgoCD admin password"
	@echo "  argo-ui               Port-forward ArgoCD UI (alias)"
	@echo "  argo-cli              Install ArgoCD CLI"

.PHONY: argo-reset
argo-reset: ## Reset ArgoCD admin password (usage: make argo-reset PASSWORD=ArgoCD123)
	@PASS=${PASSWORD:-ArgoCD123}; \
	HASH=$$(htpasswd -nbBC 10 admin $$PASS | cut -d: -f2); \
	kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "'$$HASH'"}}'; \
	kubectl -n argocd delete pods --all --grace-period=0 --force 2>/dev/null || true

.PHONY: argo-ui
argo-ui: ## Port-forward ArgoCD UI
	@echo "$(YELLOW)🔗 Access: https://localhost:$(ARGOCD_SERVER_PORT)$(RESET)"
	@kubectl -n argocd port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443

.PHONY: argo-cli
argo-cli: ## Install ArgoCD CLI
	@curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
	@sudo install -m 555 argocd /usr/local/bin/argocd && rm argocd