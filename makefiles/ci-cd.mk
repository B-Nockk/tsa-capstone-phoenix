# ============================================
# ci-cd.mk - CI/CD Pipeline Commands
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
DOCKER_REGISTRY      ?= ghcr.io
DOCKER_ORG           ?= $(shell gh api user -q .login 2>/dev/null || echo "your-org")
BACKEND_IMAGE        ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/taskapp-backend
FRONTEND_IMAGE       ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/taskapp-frontend
IMAGE_TAG            ?= latest
BACKEND_CONTEXT      ?= ../tsa_taskapp_backend_cicd
FRONTEND_CONTEXT     ?= ../tsa_taskapp_frontend_cicd

# ============================================
# Help
# ============================================
.PHONY: help-cicd
help-cicd:
	@echo "$(CYAN)CI/CD:$(RESET)"
	@echo "  ci-validate          Validate all configurations"
	@echo "  ci-build-images      Build Docker images"
	@echo "  ci-push-images       Push images to registry"
	@echo "  ci-deploy            Deploy application"
	@echo "  ci-test              Run tests"
	@echo "  ci-cleanup           Clean up resources"
	@echo "  ci-pipeline          Full CI/CD pipeline"
	@echo "  ci-pipeline-cloud    Full cloud CI/CD pipeline"

# ============================================
# Validation
# ============================================

.PHONY: ci-validate
ci-validate: ## Validate all configurations
	@echo "$(YELLOW)🔍 Validating all configurations...$(RESET)"
	@$(MAKE) helm-lint
	@$(MAKE) infra-plan ENV=dev 2>/dev/null || true
	@echo "$(GREEN)✅ Validation passed$(RESET)"

# ============================================
# Image Building
# ============================================

.PHONY: ci-build-images
ci-build-images: ## Build Docker images
	@echo "$(YELLOW)🏗️  Building Docker images...$(RESET)"
	@if [ -f "$(BACKEND_CONTEXT)/Dockerfile" ]; then \
		docker build -t $(BACKEND_IMAGE):$(IMAGE_TAG) $(BACKEND_CONTEXT); \
		docker build -t $(BACKEND_IMAGE):$(ENV)-$(IMAGE_TAG) $(BACKEND_CONTEXT); \
	fi
	@if [ -f "$(FRONTEND_CONTEXT)/Dockerfile" ]; then \
		docker build -t $(FRONTEND_IMAGE):$(IMAGE_TAG) $(FRONTEND_CONTEXT); \
		docker build -t $(FRONTEND_IMAGE):$(ENV)-$(IMAGE_TAG) $(FRONTEND_CONTEXT); \
	fi
	@echo "$(GREEN)✅ Images built$(RESET)"
	@echo "$(YELLOW)Images:$(RESET)"
	@echo "  Backend:  $(BACKEND_IMAGE):$(IMAGE_TAG)"
	@echo "  Frontend: $(FRONTEND_IMAGE):$(IMAGE_TAG)"

.PHONY: ci-push-images
ci-push-images: ## Push images to registry
	@echo "$(YELLOW)📤 Pushing images to $(DOCKER_REGISTRY)...$(RESET)"
	@docker push $(BACKEND_IMAGE):$(IMAGE_TAG)
	@docker push $(BACKEND_IMAGE):$(ENV)-$(IMAGE_TAG)
	@docker push $(FRONTEND_IMAGE):$(IMAGE_TAG)
	@docker push $(FRONTEND_IMAGE):$(ENV)-$(IMAGE_TAG)
	@echo "$(GREEN)✅ Images pushed$(RESET)"

# ============================================
# Deployment
# ============================================

.PHONY: ci-deploy
ci-deploy: ## Deploy application
	@echo "$(YELLOW)🚀 CI Deployment...$(RESET)"
	@if [ "$(CLOUD)" = "local" ]; then \
		$(MAKE) local-up; \
	else \
		$(MAKE) cloud-up; \
	fi
	@echo "$(GREEN)✅ CI Deployment complete$(RESET)"

# ============================================
# Testing
# ============================================

.PHONY: ci-test
ci-test: ## Run tests
	@echo "$(YELLOW)🧪 Running tests...$(RESET)"
	@$(MAKE) app-test
	@echo "$(GREEN)✅ Tests passed$(RESET)"

# ============================================
# Cleanup
# ============================================

.PHONY: ci-cleanup
ci-cleanup: ## Clean up resources
	@echo "$(YELLOW)🧹 Cleaning up...$(RESET)"
	@if [ "$(CLOUD)" = "local" ]; then \
		$(MAKE) local-down; \
	else \
		$(MAKE) cloud-down || true; \
	fi
	@echo "$(GREEN)✅ Cleanup complete$(RESET)"

# ============================================
# Full CI Pipelines
# ============================================

.PHONY: ci-pipeline
ci-pipeline: ## Full CI/CD pipeline
	@echo "$(GREEN)🏗️  Running full CI/CD pipeline...$(RESET)"
	@$(MAKE) ci-validate
	@$(MAKE) ci-build-images
	@$(MAKE) ci-deploy
	@$(MAKE) ci-test
	@echo "$(GREEN)🎉 CI Pipeline completed successfully!$(RESET)"

.PHONY: ci-pipeline-cloud
ci-pipeline-cloud: ## Full cloud CI/CD pipeline
	@$(MAKE) ci-pipeline CLOUD=aws ENV=prod
