# ============================================
# k8s/cluster.mk - Kubernetes Cluster Management
# ============================================
K3D_CLUSTER_NAME ?= $(PROJECT_NAME)-$(ENV)
K3D_PORT_MAPPING ?= 8080:80@loadbalancer
K3D_SERVERS      ?= 1
K3D_AGENTS       ?= 2
K3S_VERSION      ?= v1.28.8+k3s1

# Note: KUBECONFIG is securely exported by the Root Makefile.
# Do not redefine it here to maintain the Single Source of Truth.

.PHONY: help-k8s-cluster
help-k8s-cluster:
	@echo "$(CYAN)Kubernetes Cluster:$(RESET)"
	@echo "  k8s-create            Create k3d/k3s cluster"
	@echo "  k8s-delete            Delete cluster"
	@echo "  k8s-context           Write cluster context to KUBECONFIG"
	@echo "  k8s-verify            Show cluster health and nodes (Evidence)"
	@echo "  k8s-get-nodes         List nodes (Evidence)"
	@echo "  k8s-get-pods          List all pods (Evidence)"

# ============================================
# Cluster Lifecycle (Local vs Cloud)
# ============================================
.PHONY: k8s-create-local
k8s-create-local: ## Create local k3d cluster
	@k3d cluster create $(K3D_CLUSTER_NAME) --servers $(K3D_SERVERS) --agents $(K3D_AGENTS) --port "$(K3D_PORT_MAPPING)" --k3s-arg "--disable=traefik@server:0" 2>/dev/null || true
	@$(MAKE) k8s-context

.PHONY: k8s-delete-local
k8s-delete-local: ## Delete local k3d cluster
	@echo "$(RED)💥 Deleting local k3d cluster...$(RESET)"
	@if k3d cluster list | grep -q "$(K3D_CLUSTER_NAME)"; then \
		echo "$(GREEN)🗑️  Found k3d cluster '$(K3D_CLUSTER_NAME)'. Deleting...$(RESET)"; \
		k3d cluster delete $(K3D_CLUSTER_NAME); \
		echo "$(GREEN)✅ k3d cluster deleted$(RESET)"; \
	else \
		echo "$(RED)❌ k3d could not find a cluster named '$(K3D_CLUSTER_NAME)'$(RESET)"; \
	fi

.PHONY: k8s-create
k8s-create: ## Create k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) k8s-create-local
else ifeq ($(CLOUD),aws)
	@echo "Cloud creation handled by Terraform and Ansible via CI/CD"
endif

.PHONY: k8s-delete
k8s-delete: ## Delete k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) k8s-delete-local
else ifeq ($(CLOUD),aws)
	@echo "Cloud deletion handled by Terraform destroy"
endif

.PHONY: k8s-context
k8s-context: ## Write cluster context to our exported KUBECONFIG
ifeq ($(CLOUD),local)
	@echo "$(YELLOW)Writing local k3d context to $(KUBECONFIG)$(RESET)"
	@k3d kubeconfig get $(K3D_CLUSTER_NAME) > $(KUBECONFIG) 2>/dev/null || true
	@chmod 600 $(KUBECONFIG)
else ifeq ($(CLOUD),aws)
	@echo "$(GREEN)Cloud context is handled dynamically via Ansible fetch to $(KUBECONFIG)$(RESET)"
endif

# ============================================
# Evidence Gathering & Status
# ============================================
.PHONY: k8s-status k8s-verify k8s-get-nodes k8s-get-pods
k8s-status: k8s-verify

k8s-verify: ## Show cluster health and info (Evidence)
	@echo "$(CYAN)Cluster Info:$(RESET)"
	@kubectl cluster-info
	@echo "\n$(CYAN)Node Status:$(RESET)"
	@kubectl get nodes -o wide

k8s-get-nodes: ## List nodes strictly
	@kubectl get nodes -o wide

k8s-get-pods: ## List all pods across all namespaces
	@kubectl get pods -A

# ============================================
# Advanced K8s TLS
# ============================================
.PHONY: k8s-cert-renew k8s-tls-complete
k8s-cert-renew: ## Force certificate renewal (usage: make k8s-cert-renew CERT_NAME=taskapp-tls)
	@kubectl -n $(NAMESPACE) delete certificate/$(CERT_NAME) 2>/dev/null || true
	@sleep 5
	@kubectl -n $(NAMESPACE) wait --for=condition=ready certificate/$(CERT_NAME) --timeout=300s 2>/dev/null || true

k8s-tls-complete: ## Complete TLS setup (cert-manager + cluster-issuer)
	@$(MAKE) k8s-cert-install
	@kubectl -n cert-manager wait --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s 2>/dev/null || true
	@$(MAKE) k8s-issuer-apply-retry
	@$(MAKE) k8s-issuer-status
