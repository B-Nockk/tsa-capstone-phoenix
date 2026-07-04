# ============================================
# secrets/sealed.mk - Secrets Management
# ============================================

# Scripts
SECRETS_SCRIPT          ?= scripts/setup-secrets.sh
INJECT_SCRIPT           ?= scripts/inject-gh-secrets.sh
DELETE_SECRETS_SCRIPT   ?= scripts/gh-secrets-delete.sh
DELETE_VARS_SCRIPT      ?= scripts/gh-vars-delete.sh

# Sealed secrets
SEALED_SECRETS_REPO ?= https://bitnami.github.io/sealed-secrets
SEALED_SECRETS_NS   ?= sealed-secrets
SEALED_SECRETS_NAME ?= sealed-secrets
SEALED_SECRET_PATH  ?= gitops/sealed-secrets/$(ENV)/sealed-secret.yaml
HELM_TIMEOUT		?= 10m

.PHONY: help-secrets
help-secrets:
	@echo "$(CYAN)Secrets Management:$(RESET)"
	@echo "  sec-generate          Generate secrets file"
	@echo "  sec-inject-gh         Inject secrets to GitHub"
	@echo "  sec-inject-cluster    Inject SealedSecret to cluster"
	@echo "	 sec-delete-secrets    Delete secrets from GitHub"
	@echo "	 sec-delete-vars       Delete variables from GitHub"
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

.PHONY: sec-delete-secrets
sec-delete-secrets:
	@chmod +x $(DELETE_SECRETS_SCRIPT) 2>/dev/null || true
	@bash $(DELETE_SECRETS_SCRIPT) $(SECRET)

.PHONY: sec-delete-vars
sec-delete-vars:
	@chmod +x $(DELETE_VARS_SCRIPT) 2>/dev/null || true
	@bash $(DELETE_VARS_SCRIPT) $(VAR)

.PHONY: sec-inject-cluster
sec-inject-cluster:
	@kubectl apply -f $(SEALED_SECRET_PATH)

.PHONY: sec-install-controller
sec-install-controller:
	@echo "$(GREEN)🔒 Installing SealedSecrets controller...$(RESET)"
	@helm repo add $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_REPO) --force-update

	@# --- OBSERVABILITY UX IMPROVEMENT ---
	@echo "$(YELLOW)⏳ Pulling image and waiting for SealedSecrets pod to be ready...$(RESET)"
	@echo "$(CYAN)   💡 This may take 2-5 minutes. Helm is waiting for the pod to report 'Ready'.$(RESET)"
	@echo "$(CYAN)   🌐 Tip: Open a new terminal and run 'kubectl get pods -n sealed-secrets -w' to watch it.$(RESET)"
	@# ------------------------------------

	@helm upgrade --install $(SEALED_SECRETS_NAME) $(SEALED_SECRETS_NAME)/sealed-secrets \
		--namespace $(SEALED_SECRETS_NS) \
		--create-namespace \
		--wait \
		--timeout $(HELM_TIMEOUT)

	@echo "⏳ Waiting for SealedSecrets pod to be ready..."
	@kubectl wait --for=condition=ready pod --all -n sealed-secrets --timeout=120s

	@echo "$(GREEN)✅ SealedSecrets controller installed$(RESET)"

# ============================================
# Secrets Status
# ============================================
.PHONY: sec-status
sec-status: ## Check SealedSecrets status
	@kubectl -n $(SEALED_SECRETS_NS) get pods
	@ls -la gitops/sealed-secrets/*/sealed-secret.yaml 2>/dev/null || echo "No sealed secrets found"
