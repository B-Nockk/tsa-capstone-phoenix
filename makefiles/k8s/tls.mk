# ============================================
# k8s/tls.mk - TLS / Certificate Management
# ============================================
CLUSTER_ISSUER_FILE ?= infra/k8s/cluster-issuer.yaml
CERT_SCRIPT         ?= scripts/get-cert-host.sh

.PHONY: help-k8s-tls
help-k8s-tls:
	@echo "$(CYAN)Kubernetes TLS:$(RESET)"
	@echo "  k8s-issuer-apply      Apply ClusterIssuer definitions"
	@echo "  k8s-issuer-status     Show ClusterIssuer status"
	@echo "  k8s-cert-get-host     Get the hostname for certificates"
	@echo "  k8s-cert-wait         Wait for certificate to be ready"
	@echo "  k8s-cert-verify       Verify TLS setup"

.PHONY: k8s-issuer-apply
k8s-issuer-apply: ## Apply ClusterIssuer definitions
	@kubectl apply -f $(CLUSTER_ISSUER_FILE) --validate=false 2>/dev/null || kubectl apply -f $(CLUSTER_ISSUER_FILE)

.PHONY: k8s-issuer-apply-retry
k8s-issuer-apply-retry: ## Apply ClusterIssuer with retry logic
	@for i in 1 2 3; do kubectl apply -f $(CLUSTER_ISSUER_FILE) 2>/dev/null && break || sleep 5; done

.PHONY: k8s-issuer-status
k8s-issuer-status: ## Show ClusterIssuer status
	@kubectl get clusterissuer -o wide

.PHONY: k8s-cert-get-host
k8s-cert-get-host: ## Get the hostname for certificates
	@bash $(CERT_SCRIPT) $(ENV) $(CLOUD) $(APP_NAME)

.PHONY: k8s-cert-wait
k8s-cert-wait: ## Wait for certificate to be ready
	@kubectl -n $(NAMESPACE) wait --for=condition=ready certificate/taskapp-tls --timeout=300s 2>/dev/null || true

.PHONY: k8s-cert-verify
k8s-cert-verify: ## Verify TLS setup
	@kubectl get certificate -A
	@kubectl get secret -A | grep -E "(tls|cert)"

# ============================================
# TLS Inspection
# ============================================
.PHONY: k8s-cert-check
k8s-cert-check: ## Check certificate status
	@kubectl get certificate -n $(NAMESPACE)
	@kubectl describe certificate -n $(NAMESPACE)
