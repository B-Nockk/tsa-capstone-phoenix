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
CERT_MANAGER_VERSION ?= 1.14.0

# Cert-manager variables
# CERT_MANAGER_NAMESPACE ?= cert-manager
# CERT_ISSUER            ?= selfsigned-cluster-issuer
# CERT_SECRET            ?= taskapp-tls

CLUSTER_ISSUER_FILE ?= infra/k8s/cluster-issuer.yaml
CERT_SCRIPT         ?= scripts/get-cert-host.sh

# ============================================
# Help
# ============================================
.PHONY: help-kubernetes
help-kubernetes:
	@echo "$(CYAN)Kubernetes:$(RESET)"
	@echo "  cluster-create       Create k3d/k3s cluster"
	@echo "  cluster-delete       Delete cluster"
	@echo "  cluster-context      Set cluster context"
	@echo "  cluster-status       Show cluster status"
	@echo "  ingress-install      Install ingress-nginx"
	@echo "  ingress-status       Show ingress status"
	@echo "  cert-manager-install Install cert-manager"
	@echo "  cert-manager-status  Show cert-manager status"
	@echo ""
	@echo "$(YELLOW)TLS / Certificate Management:$(RESET)"
	@echo "  cluster-issuer-apply    Apply ClusterIssuer definitions"
	@echo "  cluster-issuer-status   Show ClusterIssuer status"
	@echo "  cert-get-host         Get the hostname for certificates"
	@echo "  cert-wait             Wait for certificate to be ready"
	@echo "  cert-status           Show certificate status"
	@echo "  cert-renew            Force certificate renewal"
	@echo "  cert-verify           Verify TLS setup"
# 	@echo "  cert-install          Install cert-manager (cert-manager-install + cluster-issuer-apply + cert-get-host)"

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
		--set webhook.timeoutSeconds=30 \
		--wait --timeout 180s 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting for cert-manager pods to be ready...$(RESET)"
	@kubectl -n cert-manager wait --for=condition=ready pod --all --timeout=180s 2>/dev/null || \
		echo "$(YELLOW)⚠️  Some pods may not be ready. Check with: kubectl -n cert-manager get pods$(RESET)"
	@echo "$(YELLOW)⏳ Waiting for webhook to be ready...$(RESET)"
	@kubectl -n cert-manager wait --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s 2>/dev/null || \
		echo "$(YELLOW)⚠️  Webhook may not be ready. Check with: kubectl -n cert-manager get pods$(RESET)"
	@echo "$(GREEN)✅ Cert-manager installed$(RESET)"
	@echo "$(YELLOW)📋 Cert-manager pods:$(RESET)"
	@kubectl -n cert-manager get pods

.PHONY: cert-manager-status
cert-manager-status: ## Show cert-manager status
	@echo "$(YELLOW)🔐 Cert-manager status:$(RESET)"
	@kubectl -n cert-manager get pods
	@echo ""
	@kubectl -n cert-manager get svc
	@echo ""
	@kubectl get validatingwebhookconfigurations | grep cert-manager || echo "Webhook configuration not found"

# ============================================
# TLS / Certificate Management
# ============================================

.PHONY: cluster-issuer-apply
cluster-issuer-apply: ## Apply ClusterIssuer definitions
	@echo "$(GREEN)🔐 Applying ClusterIssuer...$(RESET)"
	@# Check if cert-manager webhook is ready
	@echo "$(YELLOW)⏳ Verifying cert-manager webhook...$(RESET)"
	@if ! kubectl -n cert-manager get pod --selector=app.kubernetes.io/component=webhook -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; then \
		echo "$(YELLOW)⏳ Waiting for webhook to be ready...$(RESET)"; \
		kubectl -n cert-manager wait --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s 2>/dev/null || \
		{ echo "$(RED)❌ Webhook not ready. Please run: kubectl -n cert-manager get pods$(RESET)"; exit 1; }; \
	fi
	@echo "$(GREEN)✅ Webhook is ready$(RESET)"
	@if [ ! -f "$(CLUSTER_ISSUER_FILE)" ]; then \
		echo "$(RED)❌ ClusterIssuer file not found: $(CLUSTER_ISSUER_FILE)$(RESET)"; \
		exit 1; \
	fi
	@kubectl apply -f $(CLUSTER_ISSUER_FILE) --validate=false 2>/dev/null || \
		(kubectl apply -f $(CLUSTER_ISSUER_FILE) 2>/dev/null || \
		echo "$(YELLOW)⚠️  Retrying after delay...$(RESET)" && sleep 10 && kubectl apply -f $(CLUSTER_ISSUER_FILE))
	@echo "$(GREEN)✅ ClusterIssuer applied$(RESET)"
	@echo "$(YELLOW)📋 Available issuers:$(RESET)"
	@kubectl get clusterissuer

# ============================================
# ClusterIssuer with Retry
# ============================================

.PHONY: cluster-issuer-apply-retry
cluster-issuer-apply-retry: ## Apply ClusterIssuer with retry logic
	@echo "$(GREEN)🔐 Applying ClusterIssuer with retry...$(RESET)"
	@for i in 1 2 3 4 5; do \
		echo "$(YELLOW)Attempt $$i...$(RESET)"; \
		if kubectl apply -f $(CLUSTER_ISSUER_FILE) 2>/dev/null; then \
			echo "$(GREEN)✅ ClusterIssuer applied on attempt $$i$(RESET)"; \
			break; \
		else \
			echo "$(YELLOW)⚠️  Attempt $$i failed, waiting 5 seconds...$(RESET)"; \
			sleep 5; \
		fi; \
	done
	@echo "$(YELLOW)📋 Available issuers:$(RESET)"
	@kubectl get clusterissuer

.PHONY: cluster-issuer-status
cluster-issuer-status: ## Show ClusterIssuer status
	@echo "$(YELLOW)🔐 ClusterIssuer status:$(RESET)"
	@kubectl get clusterissuer -o wide
	@echo ""
	@echo "$(YELLOW)📋 ClusterIssuer details:$(RESET)"
	@kubectl describe clusterissuer 2>/dev/null | grep -A5 "Status:"

.PHONY: cert-get-host
cert-get-host: ## Get the hostname for certificates
	@if [ ! -f "$(CERT_SCRIPT)" ]; then \
		echo "$(RED)❌ Script not found: $(CERT_SCRIPT)$(RESET)"; \
		exit 1; \
	fi
	@chmod +x $(CERT_SCRIPT)
	@HOST=$$($(CERT_SCRIPT) $(ENV) $(CLOUD) taskapp); \
	echo "$$HOST"

.PHONY: cert-wait
cert-wait: ## Wait for certificate to be ready (usage: make cert-wait CERT_NAME=taskapp-tls)
	@test -n "$(CERT_NAME)" || (echo "$(RED)Usage: make cert-wait CERT_NAME=taskapp-tls$(RESET)"; exit 1)
	@echo "$(YELLOW)⏳ Waiting for certificate $(CERT_NAME)...$(RESET)"
	@kubectl -n $(NAMESPACE) wait --for=condition=ready certificate/$(CERT_NAME) --timeout=300s 2>/dev/null || \
		echo "$(YELLOW)⚠️  Certificate not ready yet. Check with: kubectl -n $(NAMESPACE) describe certificate $(CERT_NAME)$(RESET)"

.PHONY: cert-renew
cert-renew: ## Force certificate renewal (usage: make cert-renew CERT_NAME=taskapp-tls)
	@test -n "$(CERT_NAME)" || (echo "$(RED)Usage: make cert-renew CERT_NAME=taskapp-tls$(RESET)"; exit 1)
	@echo "$(YELLOW)🔄 Renewing certificate $(CERT_NAME)...$(RESET)"
	@kubectl -n $(NAMESPACE) delete certificate/$(CERT_NAME) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting for re-creation...$(RESET)"
	@sleep 5
	@kubectl -n $(NAMESPACE) wait --for=condition=ready certificate/$(CERT_NAME) --timeout=300s 2>/dev/null || \
		echo "$(YELLOW)⚠️  Certificate not ready. Check: kubectl -n $(NAMESPACE) describe certificate $(CERT_NAME)$(RESET)"

# ============================================
# Certificate Status & Verification
# ============================================

.PHONY: cert-status
cert-status: ## Show certificate status
	@echo "$(YELLOW)🔐 Certificate status:$(RESET)"
	@kubectl get certificate -A
	@echo ""
	@echo "$(YELLOW)📋 Certificate details:$(RESET)"
	@kubectl describe certificate -A 2>/dev/null | grep -A10 "Status:"

.PHONY: cert-verify
cert-verify: ## Verify TLS setup
	@echo "$(YELLOW)🔐 TLS Setup Verification:$(RESET)"
	@echo ""
	@echo "$(YELLOW)1. Cert-manager pods:$(RESET)"
	@kubectl -n cert-manager get pods
	@echo ""
	@echo "$(YELLOW)2. ClusterIssuers:$(RESET)"
	@kubectl get clusterissuer
	@echo ""
	@echo "$(YELLOW)3. Certificates:$(RESET)"
	@kubectl get certificate -A
	@echo ""
	@echo "$(YELLOW)4. Certificate secrets:$(RESET)"
	@kubectl get secret -A | grep -E "(tls|cert)"
	@echo ""
	@echo "$(YELLOW)5. Ingress with TLS:$(RESET)"
	@kubectl get ingress -A
	@echo ""
	@echo "$(YELLOW)6. Webhook status:$(RESET)"
	@kubectl -n cert-manager get pod --selector=app.kubernetes.io/component=webhook -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null && echo " - Webhook ready" || echo " - Webhook not ready"

# ============================================
# TLS Setup (Complete Flow)
# ============================================

.PHONY: tls-setup-complete
tls-setup-complete: ## Complete TLS setup (cert-manager + cluster-issuer)
	@echo "$(GREEN)🔐 Starting complete TLS setup...$(RESET)"
	@# Step 1: Install cert-manager
	@echo "$(YELLOW)📦 Step 1: Installing cert-manager...$(RESET)"
	@$(MAKE) cert-manager-install
	@# Step 2: Wait for webhook
	@echo "$(YELLOW)⏳ Step 2: Waiting for webhook...$(RESET)"
	@kubectl -n cert-manager wait --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s 2>/dev/null || true
	@# Step 3: Apply ClusterIssuer with retry
	@echo "$(YELLOW)🔐 Step 3: Applying ClusterIssuer...$(RESET)"
	@$(MAKE) cluster-issuer-apply-retry
	@# Step 4: Verify
	@echo "$(YELLOW)📊 Step 4: Verification...$(RESET)"
	@$(MAKE) cluster-issuer-status
	@echo "$(GREEN)✅ TLS setup complete!$(RESET)"