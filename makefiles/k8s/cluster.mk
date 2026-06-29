# ============================================
# k8s/cluster.mk - Kubernetes Cluster Management
# ============================================
K3D_CLUSTER_NAME ?= taskapp-$(ENV)
K3D_PORT_MAPPING ?= 8080:80@loadbalancer
K3D_SERVERS      ?= 1
K3D_AGENTS       ?= 2
K3S_VERSION      ?= v1.28.8+k3s1
KUBECONFIG_PATH  ?= $(HOME)/.kube/config

.PHONY: help-k8s-cluster
help-k8s-cluster:
	@echo "$(CYAN)Kubernetes Cluster:$(RESET)"
	@echo "  k8s-create            Create k3d/k3s cluster"
	@echo "  k8s-delete            Delete cluster"
	@echo "  k8s-context           Set cluster context"
	@echo "  k8s-status            Show cluster status"

.PHONY: k8s-create-local
k8s-create-local: ## Create local k3d cluster
	@k3d cluster create $(K3D_CLUSTER_NAME) --servers $(K3D_SERVERS) --agents $(K3D_AGENTS) --port "$(K3D_PORT_MAPPING)" --k3s-arg "--disable=traefik@server:0" 2>/dev/null || true
	@$(MAKE) k8s-context

.PHONY: k8s-delete-local
k8s-delete-local: ## Delete local k3d cluster
	@k3d cluster delete $(K3D_CLUSTER_NAME) 2>/dev/null || true

.PHONY: k8s-context-cloud
k8s-context-cloud: ## Switch to cloud cluster context
	@cd $(TERRAFORM_DIR) && terraform output -raw kubeconfig_command 2>/dev/null | bash || true

.PHONY: k8s-create
k8s-create: ## Create k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) k8s-create-local
else ifeq ($(CLOUD),aws)
	@echo "Cloud creation handled by Terraform (tf-apply)"
endif

.PHONY: k8s-delete
k8s-delete: ## Delete k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) k8s-delete-local
endif

.PHONY: k8s-context
k8s-context: ## Set cluster context
ifeq ($(CLOUD),local)
	@export KUBECONFIG=$$(k3d kubeconfig write $(K3D_CLUSTER_NAME)) && kubectl config use-context k3d-$(K3D_CLUSTER_NAME) 2>/dev/null || true
else ifeq ($(CLOUD),aws)
	@$(MAKE) k8s-context-cloud
endif

.PHONY: k8s-status
k8s-status: ## Show cluster status
	@kubectl cluster-info 2>/dev/null || echo "$(RED)❌ Cannot connect$(RESET)"
	@kubectl get nodes -o wide 2>/dev/null || true

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
