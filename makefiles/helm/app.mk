# ============================================
# helm/app.mk - Helm App Lifecycle
# ============================================
HELM_DIR           ?= helm/taskapp
SECRETS_DIR        ?= .secrets
LOCAL_SECRETS_FILE ?= $(SECRETS_DIR)/$(ENV).env

.PHONY: help-helm-app
help-helm-app:
	@echo "$(CYAN)Helm App Lifecycle:$(RESET)"
	@echo "  helm-deploy           Deploy/upgrade application via Helm"
	@echo "  helm-deploy-cloud     Deploy to cloud with TLS"
	@echo "  helm-rollback         Rollback application"
	@echo "  helm-uninstall        Uninstall application"
	@echo "  helm-status           Show deployment status"
	@echo "  helm-lint             Lint Helm chart"

.PHONY: helm-secrets-local
helm-secrets-local: ## Generate local secrets
	@mkdir -p $(SECRETS_DIR)
	@if [ ! -f $(LOCAL_SECRETS_FILE) ]; then \
		echo "POSTGRES_PASSWORD=$$(openssl rand -base64 32)" > $(LOCAL_SECRETS_FILE); \
		echo "SECRET_KEY=$$(openssl rand -base64 32)" >> $(LOCAL_SECRETS_FILE); \
	fi

.PHONY: helm-deploy
helm-deploy: ## Deploy/upgrade application via Helm
ifeq ($(ENV),dev)
	@$(MAKE) helm-secrets-local
	@bash -c 'set -a; source $(LOCAL_SECRETS_FILE); set +a; helm upgrade --install taskapp $(HELM_DIR) --namespace $(NAMESPACE) --create-namespace --values $(HELM_DIR)/values-$(ENV).yaml --set secrets.postgresPassword=$$POSTGRES_PASSWORD --set secrets.secretKey=$$SECRET_KEY'
else
	@helm upgrade --install taskapp $(HELM_DIR) --namespace $(NAMESPACE) --create-namespace --values $(HELM_DIR)/values-$(ENV).yaml --set secrets.postgresPassword=$$POSTGRES_PASSWORD --set secrets.secretKey=$$SECRET_KEY
endif

.PHONY: helm-deploy-cloud
helm-deploy-cloud: ## Deploy to cloud with TLS
	@helm upgrade --install taskapp $(HELM_DIR) --namespace $(NAMESPACE) --create-namespace --values $(HELM_DIR)/values-prod.yaml --set secrets.postgresPassword=$$POSTGRES_PASSWORD --set secrets.secretKey=$$SECRET_KEY --set ingress.hosts[0].host=$(HOST) --set ingress.tls.enabled=true

.PHONY: helm-rollback
helm-rollback: ## Rollback application
	@helm rollback taskapp -n $(NAMESPACE)

.PHONY: helm-uninstall
helm-uninstall: ## Uninstall application
	@helm uninstall taskapp -n $(NAMESPACE) || true

.PHONY: helm-status
helm-status: ## Show deployment status
	@helm list -n $(NAMESPACE)
	@kubectl -n $(NAMESPACE) get pods,svc,ingress

.PHONY: helm-lint
helm-lint: ## Lint Helm chart
	@helm lint $(HELM_DIR) --values $(HELM_DIR)/values-$(ENV).yaml

# ============================================
# Helm Debugging & History
# ============================================
.PHONY: helm-history helm-template helm-dry-run
helm-history: ## Show release history
	@helm history taskapp -n $(NAMESPACE)

helm-template: ## Render Helm templates
	@helm template taskapp $(HELM_DIR) --values $(HELM_DIR)/values-$(ENV).yaml

helm-dry-run: ## Dry run Helm deployment
	@helm upgrade --install taskapp $(HELM_DIR) \
		--namespace $(NAMESPACE) \
		--values $(HELM_DIR)/values-$(ENV).yaml \
		--dry-run --debug
