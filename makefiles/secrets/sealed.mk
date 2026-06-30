# ============================================
# secrets/sealed.mk - Secrets Management
# ============================================
SECRETS_SCRIPT      ?= scripts/setup-secrets.sh
INJECT_SCRIPT       ?= scripts/inject-gh-secrets.sh
SEALED_SECRETS_REPO ?= https://bitnami.github.io/sealed-secrets
SEALED_SECRETS_NS   ?= sealed-secrets
SEALED_SECRETS_NAME ?= sealed-secrets
SEALED_SECRET_PATH  ?= gitops/sealed-secrets/$(ENV)/sealed-secret.yaml

.PHONY: help-secrets
help-secrets:
	@echo "$(CYAN)Secrets Management:$(RESET)"
	@echo "  sec-generate          Generate secrets file"
	@echo "  sec-inject-gh         Inject secrets to GitHub"
	@echo "  sec-inject-cluster    Inject SealedSecret to cluster"
	@echo "  sec-install-controller Install SealedSecrets controller"

.PHONY: sec-generate
sec-generate:
	@chmod +x $(SECRETS_SCRIPT) $(INJECT_SCRIPT) 2>/dev/null || true
	@echo "$(YELLOW)🔐 Generating secrets with Make variables...$(RESET)"
	@# Export Make variables so the bash script inherits them perfectly
	@APP_NAMESPACE=$(NAMESPACE) \
	 SECRET_NAME=$(PROJECT_NAME)-secrets \
	 SEALED_NAMESPACE=$(SEALED_SECRETS_NS) \
	 SEALED_CONTROLLER_NAME=$(SEALED_SECRETS_NAME) \
	 AUTO_INJECT=true \
	 bash $(SECRETS_SCRIPT) $(ENV)

.PHONY: sec-inject-gh
sec-inject-gh:
	@bash $(INJECT_SCRIPT) $(ENV)

.PHONY: sec-inject-cluster
sec-inject-cluster:
	@kubectl apply -f $(SEALED_SECRET_PATH)

.PHONY: sec-install-controller
sec-install-controller:
	@helm repo add $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_REPO) --force-update
	@helm upgrade --install $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_NAME)/sealed-secrets --namespace $(SEALED_SECRETS_NS) --create-namespace --wait

# ============================================
# Secrets Status
# ============================================
.PHONY: sec-status
sec-status: ## Check SealedSecrets status
	@kubectl -n $(SEALED_SECRETS_NS) get pods
	@ls -la gitops/sealed-secrets/*/sealed-secret.yaml 2>/dev/null || echo "No sealed secrets found"
