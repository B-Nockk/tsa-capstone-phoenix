# ============================================
# k8s/ingress.mk - Ingress Controller
# ============================================
INGRESS_NGINX_VERSION ?= 4.15.1

.PHONY: help-k8s-ingress
help-k8s-ingress:
	@echo "$(CYAN)Kubernetes Ingress:$(RESET)"
	@echo "  k8s-ingress-install   Install ingress-nginx"
	@echo "  k8s-ingress-uninstall Uninstall ingress-nginx"
	@echo "  k8s-ingress-status    Show ingress status"

.PHONY: k8s-ingress-install
k8s-ingress-install: ## Install ingress-nginx
	@echo "$(GREEN)🌐 Installing ingress-nginx...$(RESET)"
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update 2>/dev/null
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --version $(INGRESS_NGINX_VERSION) --set controller.replicaCount=1 --set controller.service.type=LoadBalancer --wait --timeout 120s 2>/dev/null || true

.PHONY: k8s-ingress-uninstall
k8s-ingress-uninstall: ## Uninstall ingress-nginx
	@helm uninstall ingress-nginx -n ingress-nginx || true

.PHONY: k8s-ingress-status
k8s-ingress-status: ## Show ingress status
	@kubectl -n ingress-nginx get pods,svc