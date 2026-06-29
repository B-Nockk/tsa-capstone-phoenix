# ============================================
# cicd/pipeline.mk - CI/CD Pipeline Commands
# ============================================
DOCKER_REGISTRY  ?= ghcr.io
DOCKER_ORG       ?= $(shell gh api user -q .login 2>/dev/null || echo "your-org")
BACKEND_IMAGE    ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/taskapp-backend
FRONTEND_IMAGE   ?= $(DOCKER_REGISTRY)/$(DOCKER_ORG)/taskapp-frontend
IMAGE_TAG        ?= latest
BACKEND_CONTEXT  ?= ../tsa_taskapp_backend_cicd
FRONTEND_CONTEXT ?= ../tsa_taskapp_frontend_cicd

.PHONY: help-cicd
help-cicd:
	@echo "$(CYAN)CI/CD:$(RESET)"
	@echo "  ci-validate          Validate all configurations"
	@echo "  ci-build-images      Build Docker images"
	@echo "  ci-push-images       Push images to registry"
	@echo "  ci-pipeline          Full CI/CD pipeline"

.PHONY: ci-validate
ci-validate: ## Validate all configurations
	@$(MAKE) helm-lint

.PHONY: ci-build-images
ci-build-images: ## Build Docker images
	@if [ -f "$(BACKEND_CONTEXT)/Dockerfile" ]; then docker build -t $(BACKEND_IMAGE):$(IMAGE_TAG) $(BACKEND_CONTEXT); fi
	@if [ -f "$(FRONTEND_CONTEXT)/Dockerfile" ]; then docker build -t $(FRONTEND_IMAGE):$(IMAGE_TAG) $(FRONTEND_CONTEXT); fi

.PHONY: ci-push-images
ci-push-images: ## Push images to registry
	@docker push $(BACKEND_IMAGE):$(IMAGE_TAG)
	@docker push $(FRONTEND_IMAGE):$(IMAGE_TAG)

.PHONY: ci-pipeline
ci-pipeline: ## Full CI/CD pipeline
	@$(MAKE) ci-validate
	@$(MAKE) ci-build-images
	@$(MAKE) ci-push-images

# ============================================
# CI/CD Wrappers
# ============================================
.PHONY: ci-deploy ci-test ci-cleanup
ci-deploy: ## Deploy application (CI wrapper)
ifeq ($(CLOUD),local)
	@$(MAKE) local-up
else
	@$(MAKE) cloud-up
endif

ci-test: ## Run tests (CI wrapper)
	@$(MAKE) helm-test-app

ci-cleanup: ## Clean up resources
ifeq ($(CLOUD),local)
	@$(MAKE) local-down
else
	@$(MAKE) cloud-down || true
endif
