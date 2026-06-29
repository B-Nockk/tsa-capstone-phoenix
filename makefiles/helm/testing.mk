# ============================================
# helm/testing.mk - Helm Testing & Debugging
# ============================================
BACKEND_INTERNAL_HOST  ?= backend
BACKEND_INTERNAL_PORT  ?= 5000
FRONTEND_INTERNAL_HOST ?= frontend
FRONTEND_INTERNAL_PORT ?= 80
BACKEND_EXTERNAL_HOST   ?= taskapp.local
BACKEND_EXTERNAL_PORT   ?= 8080
POSTGRES_HOST          ?= postgres
POSTGRES_PORT          ?= 5432
POSTGRES_USER          ?= taskapp_user
POSTGRES_DB            ?= taskapp

BACKEND_HEALTH_URL     := http://$(BACKEND_INTERNAL_HOST):$(BACKEND_INTERNAL_PORT)/api/health
FRONTEND_URL           := http://$(FRONTEND_INTERNAL_HOST):$(FRONTEND_INTERNAL_PORT)/
POSTGRES_CHECK_URL     := $(POSTGRES_HOST):$(POSTGRES_PORT)/$(POSTGRES_DB)

.PHONY: help-helm-testing
help-helm-testing:
	@echo "$(CYAN)Helm Testing:$(RESET)"
	@echo "  helm-test-app         Test application from inside cluster"
	@echo "  helm-test-external    Test application from outside cluster"
	@echo "  helm-app-logs         Show application logs"
	@echo "  helm-app-shell        Shell into backend pod"
	@echo "  helm-app-psql         Connect to PostgreSQL"

.PHONY: helm-test-app
helm-test-app: ## Test application from inside cluster
	@echo "$(YELLOW)🧪 Testing TaskApp...$(RESET)"
	@kubectl -n $(NAMESPACE) run test-api --rm -it --restart=Never --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" $(BACKEND_HEALTH_URL) 2>/dev/null | grep -q "200" && echo "✅ API OK" || echo "❌ API Failed"

.PHONY: helm-test-external
helm-test-external: ## Test application from outside cluster
	@curl -s http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)/api/health | jq '.' 2>/dev/null || curl -s http://$(BACKEND_EXTERNAL_HOST):$(BACKEND_EXTERNAL_PORT)/api/health

.PHONY: helm-app-logs
helm-app-logs: ## Show application logs
	@kubectl -n $(NAMESPACE) logs -f --all-containers --tail=50

.PHONY: helm-app-shell
helm-app-shell: ## Shell into backend pod
	@kubectl -n $(NAMESPACE) exec -it deployment/backend -- /bin/sh

.PHONY: helm-app-psql
helm-app-psql: ## Connect to PostgreSQL
	@kubectl -n $(NAMESPACE) exec -it statefulset/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)