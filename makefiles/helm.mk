# ============================================
# helm.mk - Helm commands
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
HELM_DIR              ?= helm/taskapp
INGRESS_NGINX_VERSION ?= 4.15.1
CERT_MANAGER_VERSION  ?= 1.20.3
CLUSTER_ISSUER_FILE   ?= infra/k8s/cluster-issuer.yaml
SECRETS_DIR           ?= .secrets
LOCAL_SECRETS_FILE    ?= $(SECRETS_DIR)/$(ENV).env

# Helm test variables (internal - for tests running inside cluster)
BACKEND_INTERNAL_HOST  ?= backend
BACKEND_INTERNAL_PORT  ?= 5000
FRONTEND_INTERNAL_HOST ?= frontend
FRONTEND_INTERNAL_PORT ?= 80

# Helm test variables (external - for tests from your browser/host)
BACKEND_EXTERNAL_HOST  ?= taskapp.local
BACKEND_EXTERNAL_PORT  ?= 8080
FRONTEND_EXTERNAL_HOST ?= taskapp.local
FRONTEND_EXTERNAL_PORT ?= 8080

# Postgres connection details
POSTGRES_HOST          ?= postgres
POSTGRES_PORT          ?= 5432
POSTGRES_USER          ?= taskapp_user
POSTGRES_DB            ?= taskapp

# Construct URLs (internal ones used by app-test)
BACKEND_HEALTH_URL     := http://$(BACKEND_INTERNAL_HOST):$(BACKEND_INTERNAL_PORT)/api/health
FRONTEND_URL           := http://$(FRONTEND_INTERNAL_HOST):$(FRONTEND_INTERNAL_PORT)/
POSTGRES_CHECK_URL     := $(POSTGRES_HOST):$(POSTGRES_PORT)/$(POSTGRES_DB)

# External URLs (for reference/quick testing from your host)
BACKEND_EXTERNAL_URL   := http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)/api/health
FRONTEND_EXTERNAL_URL  := http://$(FRONTEND_EXTERNAL_HOST):$(FRONTEND_EXTERNAL_PORT)/

# ============================================
# Help
# ============================================
.PHONY: help-helm
help-helm:
	@echo "$(CYAN)Helm:$(RESET)"
	@echo "  helm-deploy          Deploy/upgrade application via Helm"
	@echo "  helm-deploy-cloud    Deploy to cloud with TLS"
	@echo "  helm-rollback        Rollback application"
	@echo "  helm-uninstall       Uninstall application"
	@echo "  helm-status          Show deployment status"
	@echo "  helm-history         Show release history"
	@echo "  helm-lint            Lint Helm chart"
	@echo "  helm-template        Render Helm templates"
	@echo "  helm-dry-run         Dry run Helm deployment"
	@echo "  app-test             Test application from inside cluster"
	@echo "  test-external        Test application from outside cluster"
	@echo "  app-logs             Show application logs"
	@echo "  app-shell            Shell into backend pod"
	@echo "  app-psql             Connect to PostgreSQL"
	@echo "  show-test-urls       Show all test URLs"
	@echo ""
	@echo "$(CYAN)Infrastructure:$(RESET)"
	@echo "  install-ingress      Install ingress-nginx"
	@echo "  uninstall-ingress    Uninstall ingress-nginx"
	@echo "  install-cert-manager Install cert-manager"
	@echo "  uninstall-cert-manager Uninstall cert-manager"
	@echo "  apply-cluster-issuer Apply ClusterIssuer"

# ============================================
# Repo Setup: Ingress Controller + Cert-Manager
# ============================================

.PHONY: install-ingress
install-ingress: ## Install ingress-nginx
	@echo "$(GREEN)Installing ingress-nginx $(INGRESS_NGINX_VERSION)...$(RESET)"
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
	helm repo update ingress-nginx
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--version $(INGRESS_NGINX_VERSION) \
		--namespace ingress-nginx --create-namespace

.PHONY: uninstall-ingress
uninstall-ingress: ## Uninstall ingress-nginx
	@echo "$(RED)Uninstalling ingress-nginx...$(RESET)"
	@helm uninstall ingress-nginx -n ingress-nginx || true

.PHONY: install-cert-manager
install-cert-manager: ## Install cert-manager
	@echo "$(GREEN)Installing cert-manager $(CERT_MANAGER_VERSION)...$(RESET)"
	helm repo add jetstack https://charts.jetstack.io --force-update
	helm repo update jetstack
	helm upgrade --install cert-manager jetstack/cert-manager \
		--version $(CERT_MANAGER_VERSION) \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true

.PHONY: uninstall-cert-manager
uninstall-cert-manager: ## Uninstall cert-manager
	@echo "$(RED)Uninstalling cert-manager...$(RESET)"
	@helm uninstall cert-manager -n cert-manager || true

# ============================================
# Cert-Manager TLS Resources
# ============================================

.PHONY: apply-cluster-issuer
apply-cluster-issuer: ## Apply ClusterIssuer
	@echo "$(GREEN)Applying ClusterIssuer from $(CLUSTER_ISSUER_FILE)...$(RESET)"
	kubectl apply -f $(CLUSTER_ISSUER_FILE)

.PHONY: check-cert
check-cert: ## Check certificate status (requires HOST variable)
	@test -n "$(HOST)" || (echo "$(RED)Usage: make check-cert HOST=taskapp.local$(RESET)"; exit 1)
	kubectl get certificate -n $(NAMESPACE)
	@echo "$(YELLOW)Certificate detail:$(RESET)"
	kubectl describe certificate -n $(NAMESPACE)

# ============================================
# App Secrets
# ============================================
# Local (ENV=dev): generate once, persist to .secrets/, reuse on every redeploy.
# Cloud/CI (ENV=prod, or anything else): POSTGRES_PASSWORD and SECRET_KEY must
# already be exported (e.g. from GitHub Actions secrets / AWS Secrets Manager).

.PHONY: secrets-local
secrets-local: ## Generate local secrets
	@mkdir -p $(SECRETS_DIR)
	@if [ ! -f $(LOCAL_SECRETS_FILE) ]; then \
		echo "$(YELLOW)No secrets found for ENV=$(ENV) — generating...$(RESET)"; \
		echo "POSTGRES_PASSWORD=$$(openssl rand -base64 32)" > $(LOCAL_SECRETS_FILE); \
		echo "SECRET_KEY=$$(openssl rand -base64 32)" >> $(LOCAL_SECRETS_FILE); \
	else \
		echo "$(YELLOW)Reusing existing secrets for ENV=$(ENV) ($(LOCAL_SECRETS_FILE))$(RESET)"; \
	fi

# ============================================
# App Lifecycle
# ============================================

.PHONY: helm-deploy
helm-deploy: ## Deploy/upgrade application via Helm
ifeq ($(ENV),dev)
	@$(MAKE) secrets-local
	@bash -c '\
		set -a; source $(LOCAL_SECRETS_FILE); set +a; \
		echo "$(GREEN)Deploying TaskApp (ENV=$(ENV))...$(RESET)"; \
		helm upgrade --install taskapp $(HELM_DIR) \
			--namespace $(NAMESPACE) --create-namespace \
			--values $(HELM_DIR)/values-$(ENV).yaml \
			--set secrets.postgresPassword=$$POSTGRES_PASSWORD \
			--set secrets.secretKey=$$SECRET_KEY \
	'
else
	@test -n "$$POSTGRES_PASSWORD" || (echo "$(RED)POSTGRES_PASSWORD env var required when ENV=$(ENV)$(RESET)"; exit 1)
	@test -n "$$SECRET_KEY" || (echo "$(RED)SECRET_KEY env var required when ENV=$(ENV)$(RESET)"; exit 1)
	@echo "$(GREEN)Deploying TaskApp (ENV=$(ENV))...$(RESET)"
	helm upgrade --install taskapp $(HELM_DIR) \
		--namespace $(NAMESPACE) --create-namespace \
		--values $(HELM_DIR)/values-$(ENV).yaml \
		--set secrets.postgresPassword=$$POSTGRES_PASSWORD \
		--set secrets.secretKey=$$SECRET_KEY
endif

.PHONY: helm-deploy-cloud
helm-deploy-cloud: ## Deploy to cloud with TLS (requires HOST variable)
	@test -n "$$POSTGRES_PASSWORD" || (echo "$(RED)POSTGRES_PASSWORD env var required$(RESET)"; exit 1)
	@test -n "$$SECRET_KEY" || (echo "$(RED)SECRET_KEY env var required$(RESET)"; exit 1)
	@test -n "$(HOST)" || (echo "$(RED)Usage: make helm-deploy-cloud HOST=<ip>.nip.io$(RESET)"; exit 1)
	@echo "$(GREEN)Deploying TaskApp to cloud (HOST=$(HOST))...$(RESET)"
	helm upgrade --install taskapp $(HELM_DIR) \
		--namespace $(NAMESPACE) --create-namespace \
		--values $(HELM_DIR)/values-prod.yaml \
		--set secrets.postgresPassword=$$POSTGRES_PASSWORD \
		--set secrets.secretKey=$$SECRET_KEY \
		--set ingress.hosts[0].host=$(HOST) \
		--set ingress.tls.enabled=true \
		--set ingress.tls.issuer=letsencrypt-prod \
		--set ingress.tls.secretName=taskapp-tls

.PHONY: helm-rollback
helm-rollback: ## Rollback application
	@echo "$(YELLOW)Rolling back taskapp release...$(RESET)"
	helm rollback taskapp -n $(NAMESPACE)

.PHONY: helm-history
helm-history: ## Show release history
	helm history taskapp -n $(NAMESPACE)

.PHONY: helm-uninstall
helm-uninstall: ## Uninstall application
	@echo "$(RED)Uninstalling TaskApp...$(RESET)"
	@helm uninstall taskapp -n $(NAMESPACE) || true

# ============================================
# Validation & Debugging
# ============================================

.PHONY: helm-lint
helm-lint: ## Lint Helm chart
	@echo "$(YELLOW)Linting chart...$(RESET)"
	helm lint $(HELM_DIR) --values $(HELM_DIR)/values-$(ENV).yaml

.PHONY: helm-template
helm-template: ## Render Helm templates
	@echo "$(YELLOW)Rendering chart (ENV=$(ENV))...$(RESET)"
	helm template taskapp $(HELM_DIR) --values $(HELM_DIR)/values-$(ENV).yaml

.PHONY: helm-dry-run
helm-dry-run: ## Dry run Helm deployment
	helm upgrade --install taskapp $(HELM_DIR) \
		--namespace $(NAMESPACE) \
		--values $(HELM_DIR)/values-$(ENV).yaml \
		--dry-run --debug

# ============================================
# Status / Inspection
# ============================================

.PHONY: helm-status
helm-status: ## Show deployment status
	@echo "$(YELLOW)Helm releases:$(RESET)"
	@helm list -n $(NAMESPACE)
	@echo "$(YELLOW)Pods:$(RESET)"
	@kubectl -n $(NAMESPACE) get pods
	@echo "$(YELLOW)Services:$(RESET)"
	@kubectl -n $(NAMESPACE) get svc
	@echo "$(YELLOW)Ingress:$(RESET)"
	@kubectl -n $(NAMESPACE) get ingress

# ============================================
# Application Testing (Internal Cluster Tests)
# ============================================

.PHONY: app-test
app-test: ## Test application from inside cluster
	@echo "$(YELLOW)🧪 Testing TaskApp from inside the cluster...$(RESET)"
	@echo ""
	@echo "$(YELLOW)1. Checking pods...$(RESET)"
	@kubectl -n $(NAMESPACE) get pods
	@echo ""
	@echo "$(YELLOW)2. Testing API health (internal: $(BACKEND_HEALTH_URL))...$(RESET)"
	@kubectl -n $(NAMESPACE) run test-api --rm -it --restart=Never --image=curlimages/curl -- \
		curl -s -o /dev/null -w "%{http_code}" $(BACKEND_HEALTH_URL) 2>/dev/null | grep -q "200" && \
		echo "$(GREEN)✅ API health check passed$(RESET)" || \
		echo "$(RED)❌ API health check failed (URL: $(BACKEND_HEALTH_URL))$(RESET)"
	@echo ""
	@echo "$(YELLOW)3. Testing frontend (internal: $(FRONTEND_URL))...$(RESET)"
	@kubectl -n $(NAMESPACE) run test-frontend --rm -it --restart=Never --image=curlimages/curl -- \
		curl -s -o /dev/null -w "%{http_code}" $(FRONTEND_URL) 2>/dev/null | grep -q "200" && \
		echo "$(GREEN)✅ Frontend check passed$(RESET)" || \
		echo "$(RED)❌ Frontend check failed (URL: $(FRONTEND_URL))$(RESET)"
	@echo ""
	@echo "$(YELLOW)4. Testing database (internal: $(POSTGRES_CHECK_URL))...$(RESET)"
	@kubectl -n $(NAMESPACE) run test-db --rm -it --restart=Never --image=postgres:16-alpine -- \
		pg_isready -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(POSTGRES_DB) 2>/dev/null | grep -q "accepting" && \
		echo "$(GREEN)✅ Database check passed$(RESET)" || \
		echo "$(RED)❌ Database check failed (Host: $(POSTGRES_HOST):$(POSTGRES_PORT), User: $(POSTGRES_USER), DB: $(POSTGRES_DB))$(RESET)"
	@echo ""
	@echo "$(GREEN)✅ All internal cluster tests passed!$(RESET)"
	@echo ""
	@echo "$(YELLOW)📝 External URLs (for browser testing):$(RESET)"
	@echo "  API:     $(BACKEND_EXTERNAL_URL)"
	@echo "  Frontend: $(FRONTEND_EXTERNAL_URL)"

# ============================================
# External Testing (From Your Host)
# ============================================

.PHONY: test-external
test-external: ## Test application from outside cluster
	@echo "$(YELLOW)🧪 Testing TaskApp from outside the cluster...$(RESET)"
	@echo ""
	@echo "$(YELLOW)Testing API: $(BACKEND_EXTERNAL_URL)$(RESET)"
	@curl -s $(BACKEND_EXTERNAL_URL) | jq '.' 2>/dev/null || curl -s $(BACKEND_EXTERNAL_URL)
	@echo ""
	@echo "$(YELLOW)Testing Frontend: $(FRONTEND_EXTERNAL_URL)$(RESET)"
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" $(FRONTEND_EXTERNAL_URL)

.PHONY: app-logs
app-logs: ## Show application logs
	@echo "$(YELLOW)📋 Showing recent logs...$(RESET)"
	@kubectl -n $(NAMESPACE) logs -f --all-containers --tail=50

.PHONY: app-shell
app-shell: ## Shell into backend pod
	@echo "$(YELLOW)🐚 Getting shell in backend pod...$(RESET)"
	@kubectl -n $(NAMESPACE) exec -it deployment/backend -- /bin/sh

.PHONY: app-psql
app-psql: ## Connect to PostgreSQL
	@echo "$(YELLOW)🐘 Connecting to PostgreSQL...$(RESET)"
	@kubectl -n $(NAMESPACE) exec -it statefulset/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

# ============================================
# Quick test helpers
# ============================================

.PHONY: show-test-urls
show-test-urls: ## Show all test URLs
	@echo "$(YELLOW)Current test URLs:$(RESET)"
	@echo ""
	@echo "$(GREEN)Internal (from inside cluster):$(RESET)"
	@echo "  API health:     $(BACKEND_HEALTH_URL)"
	@echo "  Frontend:       $(FRONTEND_URL)"
	@echo "  Postgres:       $(POSTGRES_CHECK_URL)"
	@echo ""
	@echo "$(GREEN)External (from your browser/host):$(RESET)"
	@echo "  API health:     $(BACKEND_EXTERNAL_URL)"
	@echo "  Frontend:       $(FRONTEND_EXTERNAL_URL)"
	@echo ""
	@echo "$(YELLOW)To override internal URLs:$(RESET)"
	@echo "  make app-test BACKEND_INTERNAL_HOST=backend BACKEND_INTERNAL_PORT=5000"
	@echo ""
	@echo "$(YELLOW)To test external URLs:$(RESET)"
	@echo "  make test-external"