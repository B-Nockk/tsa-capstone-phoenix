# ============================================
# argo/management.mk - ArgoCD Management
# ============================================
ARGOCD_RESET_PASSWORD ?= true
ARGOCD_DEFAULT_PASS   ?= ArgoCD123

.PHONY: help-argo-management
help-argo-management:
	@echo "$(CYAN)ArgoCD Management:$(RESET)"
	@echo "  argo-reset            Reset ArgoCD admin password"
	@echo "  argo-ui               Port-forward ArgoCD UI (alias)"
	@echo "  argo-cli              Install ArgoCD CLI"
	@echo "  argo-password         Get current ArgoCD admin password"

.PHONY: argo-reset
argo-reset: ## Reset ArgoCD admin password (usage: make argo-reset PASSWORD=MyPass123)
	@PASS=$${PASSWORD:-$(ARGOCD_DEFAULT_PASS)}; \
	echo "$(YELLOW)🔑 Setting ArgoCD password to: $$PASS$(RESET)"; \
	HASH=$$(htpasswd -nbB admin "$$PASS" | cut -d: -f2); \
	if [ -z "$$HASH" ]; then \
		echo "$(RED)❌ Failed to generate password hash. Is htpasswd installed?$(RESET)"; \
		echo "$(YELLOW)   Install with: sudo apt install apache2-utils$(RESET)"; \
		exit 1; \
	fi; \
	kubectl -n $(ARGOCD_NAMESPACE) patch secret argocd-secret \
		-p '{"stringData": {"admin.password": "'$$HASH'", "admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'; \
	kubectl -n $(ARGOCD_NAMESPACE) scale deployment argocd-server --replicas=0; \
	sleep 2; \
	kubectl -n $(ARGOCD_NAMESPACE) scale deployment argocd-server --replicas=1; \
	kubectl -n $(ARGOCD_NAMESPACE) rollout status deployment/argocd-server --timeout=120s; \
	echo "$(GREEN)✅ Password reset to: $$PASS$(RESET)"

.PHONY: argo-ui
argo-ui: ## Port-forward ArgoCD UI
# argo-ui: argo-portforward ## Port-forward ArgoCD UI (alias)
	@echo "$(YELLOW)🔗 Access: https://localhost:$(ARGOCD_SERVER_PORT)$(RESET)"
	@kubectl -n argocd port-forward svc/argocd-server $(ARGOCD_SERVER_PORT):443

.PHONY: argo-cli
argo-cli: ## Install ArgoCD CLI
	@curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
	@sudo install -m 555 argocd /usr/local/bin/argocd && rm argocd
	@echo "$(GREEN)✅ ArgoCD CLI installed$(RESET)"
