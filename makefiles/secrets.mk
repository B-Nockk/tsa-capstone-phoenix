# ============================================
# Configurable Variables (env override)
# ============================================

SECRETS_SCRIPT         ?= scripts/setup-secrets.sh
INJECT_SCRIPT          ?= scripts/inject-gh-secrets.sh
SEALED_SECRETS_REPO    ?= https://bitnami.github.io/sealed-secrets
SEALED_SECRETS_NS      ?= sealed-secrets
SEALED_SECRETS_NAME    ?= sealed-secrets
SEALED_SECRET_PATH     ?= gitops/sealed-secrets/$(ENV)/sealed-secret.yaml
ENV                    ?= dev   # default environment

# ============================================
# Secrets Management
# ============================================

.PHONY: help-secrets
help-secrets:
	@echo "$(CYAN)Secrets Management:$(RESET)"
	@echo "  secrets-generate         Generate secrets file for current environment"
	@echo "  secrets-inject-gh        Inject secrets to GitHub repository"
	@echo "  secrets-inject-cluster   Inject SealedSecret to cluster"
	@echo "  secrets-install-controller Install SealedSecrets controller"
	@echo "  secrets-status           Check SealedSecrets status"
	@echo ""
	@echo "$(YELLOW)Note:$(RESET) Run this BEFORE deploying the first time."
	@echo "      Secrets are encrypted using SealedSecrets and stored in Git."

.PHONY: secrets-generate
secrets-generate:
	@chmod +x $(SECRETS_SCRIPT) $(INJECT_SCRIPT) 2>/dev/null || true
	@bash $(SECRETS_SCRIPT) $(ENV)

.PHONY: secrets-inject-gh
secrets-inject-gh:
	@bash $(INJECT_SCRIPT) $(ENV)

.PHONY: secrets-inject-cluster
secrets-inject-cluster:
	@echo "$(YELLOW)🔑 Injecting SealedSecret to cluster...$(RESET)"
	@kubectl apply -f $(SEALED_SECRET_PATH)

.PHONY: secrets-install-controller
secrets-install-controller:
	@echo "$(GREEN)🔒 Installing SealedSecrets controller...$(RESET)"
	@helm repo add $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_REPO) --force-update
	@helm upgrade --install $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_NAME)/sealed-secrets \
		--namespace $(SEALED_SECRETS_NS) --create-namespace \
		--wait
	@echo "$(GREEN)✅ SealedSecrets controller installed$(RESET)"

.PHONY: secrets-status
secrets-status:
	@echo "$(YELLOW)🔐 SealedSecrets status:$(RESET)"
	@kubectl -n $(SEALED_SECRETS_NS) get pods
	@echo ""
	@echo "$(YELLOW)🔐 SealedSecrets in git:$(RESET)"
	@ls -la gitops/sealed-secrets/*/sealed-secret.yaml 2>/dev/null || echo "No sealed secrets found"
