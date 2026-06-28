# ============================================
# kubernetes.mk - Kubernetes Cluster Management
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
K3D_CLUSTER_NAME  ?= taskapp-$(ENV)
K3D_PORT_MAPPING  ?= 8080:80@loadbalancer
K3D_SERVERS       ?= 1
K3D_AGENTS        ?= 2
K3S_VERSION       ?= v1.28.8+k3s1
KUBECONFIG_PATH   ?= $(HOME)/.kube/config

# These are inherited from common.mk but can be overridden
INGRESS_NGINX_VERSION ?= 4.15.1
CERT_MANAGER_VERSION  ?= 1.20.3

# ============================================
# Help
# ============================================
.PHONY: help-raw
help-raw:
	@echo "$(CYAN)Kubernetes:$(RESET)"
	@echo "  cluster-create       Create k3d/k3s cluster"
	@echo "  cluster-delete       Delete cluster"
	@echo "  cluster-context      Set cluster context"
	@echo "  cluster-status       Show cluster status"
	@echo "  ingress-install      Install ingress-nginx"
	@echo "  ingress-status       Show ingress status"
	@echo "  cert-manager-install Install cert-manager"
	@echo "  cert-manager-status  Show cert-manager status"

# ============================================
# Local Cluster (k3d)
# ============================================

.PHONY: cluster-create-local
cluster-create-local: ## Create local k3d cluster
	@echo "$(GREEN)🔄 Creating local k3d cluster...$(RESET)"
	@k3d cluster create $(K3D_CLUSTER_NAME) \
		--servers $(K3D_SERVERS) \
		--agents $(K3D_AGENTS) \
		--port "$(K3D_PORT_MAPPING)" \
		--k3s-arg "--disable=traefik@server:0" \
		--k3s-arg "--flannel-backend=host-gw@server:0" \
		--volume "$(KUBECONFIG_PATH):/home/ubuntu/.kube/config" \
		2>/dev/null || true
	@$(MAKE) cluster-context
	@echo "$(GREEN)✅ Cluster created!$(RESET)"

.PHONY: cluster-delete-local
cluster-delete-local: ## Delete local k3d cluster
	@echo "$(RED)💥 Deleting local cluster...$(RESET)"
	@k3d cluster delete $(K3D_CLUSTER_NAME) 2>/dev/null || true
	@echo "$(GREEN)✅ Cluster deleted$(RESET)"

# ============================================
# Cloud Cluster (k3s via Terraform + Ansible)
# ============================================

.PHONY: cluster-context-cloud
cluster-context-cloud: ## Switch to cloud cluster context
	@echo "$(YELLOW)🔄 Switching to cloud cluster context...$(RESET)"
	@cd $(TERRAFORM_DIR) && terraform output -raw kubeconfig_command 2>/dev/null | bash || \
		echo "$(RED)❌ Cloud cluster not found. Run 'make infra-apply' first.$(RESET)"
	@echo "$(GREEN)✅ Cloud context set$(RESET)"

# ============================================
# Generic Cluster Commands
# ============================================

.PHONY: cluster-create
cluster-create: ## Create k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) cluster-create-local
else ifeq ($(CLOUD),aws)
	@$(MAKE) cluster-create-cloud
else
	@echo "$(RED)❌ Unknown CLOUD=$(CLOUD). Use 'local' or 'aws'$(RESET)"
	@exit 1
endif

.PHONY: cluster-delete
cluster-delete: ## Delete k3d/k3s cluster
ifeq ($(CLOUD),local)
	@$(MAKE) cluster-delete-local
else ifeq ($(CLOUD),aws)
	@$(MAKE) cluster-delete-cloud
else
	@echo "$(RED)❌ Unknown CLOUD=$(CLOUD). Use 'local' or 'aws'$(RESET)"
	@exit 1
endif

.PHONY: cluster-context
cluster-context: ## Set cluster context
ifeq ($(CLOUD),local)
	@export KUBECONFIG=$$(k3d kubeconfig write $(K3D_CLUSTER_NAME)) && \
		kubectl config use-context k3d-$(K3D_CLUSTER_NAME) 2>/dev/null || true
	@echo "$(GREEN)✅ Using local cluster context$(RESET)"
else ifeq ($(CLOUD),aws)
	@$(MAKE) cluster-context-cloud
else
	@echo "$(YELLOW)⚠️  Unknown CLOUD=$(CLOUD). Using current context.$(RESET)"
endif

.PHONY: cluster-status
cluster-status: ## Show cluster status
	@echo "$(YELLOW)📊 Cluster status:$(RESET)"
	@kubectl cluster-info 2>/dev/null || echo "$(RED)❌ Cannot connect to cluster$(RESET)"
	@echo ""
	@kubectl get nodes -o wide 2>/dev/null || echo "$(RED)❌ No nodes found$(RESET)"
	@echo ""
	@kubectl get pods -A 2>/dev/null | head -20 || echo "$(RED)❌ No pods found$(RESET)"

# ============================================
# Ingress Controller
# ============================================

.PHONY: ingress-install
ingress-install: ## Install ingress-nginx
	@echo "$(GREEN)🌐 Installing ingress-nginx...$(RESET)"
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update 2>/dev/null
	@helm repo update ingress-nginx 2>/dev/null
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx --create-namespace \
		--version $(INGRESS_NGINX_VERSION) \
		--set controller.replicaCount=1 \
		--set controller.service.type=LoadBalancer \
		--wait --timeout 120s 2>/dev/null || true
	@echo "$(GREEN)✅ Ingress controller installed$(RESET)"

.PHONY: ingress-status
ingress-status: ## Show ingress status
	@echo "$(YELLOW)🌐 Ingress status:$(RESET)"
	@kubectl -n ingress-nginx get pods,svc
	@echo ""
	@kubectl -n $(NAMESPACE) get ingress 2>/dev/null || echo "No ingress resources found"

# ============================================
# Cert-Manager (for TLS)
# ============================================

.PHONY: cert-manager-install
cert-manager-install: ## Install cert-manager
	@echo "$(GREEN)🔐 Installing cert-manager...$(RESET)"
	@helm repo add jetstack https://charts.jetstack.io --force-update 2>/dev/null
	@helm repo update jetstack 2>/dev/null
	@helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--version $(CERT_MANAGER_VERSION) \
		--set crds.enabled=true \
		--wait --timeout 120s 2>/dev/null || true
	@echo "$(GREEN)✅ Cert-manager installed$(RESET)"

.PHONY: cert-manager-status
cert-manager-status: ## Show cert-manager status
	@echo "$(YELLOW)🔐 Cert-manager status:$(RESET)"
	@kubectl -n cert-manager get pods