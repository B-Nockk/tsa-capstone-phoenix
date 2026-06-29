# ============================================
# diag/tls.mk - TLS Diagnostics
# ============================================
.PHONY: help-diag-tls
help-diag-tls:
	@echo "$(CYAN)TLS Diagnostics:$(RESET)"
	@echo "  diag-tls              Diagnose TLS/cert issues"

.PHONY: diag-tls
diag-tls: ## Diagnose TLS/cert issues
	@echo "$(YELLOW)🔐 TLS/Cert Diagnostics:$(RESET)"
	@kubectl get namespace cert-manager 2>/dev/null || echo "cert-manager namespace not found"
	@kubectl -n cert-manager get pods 2>/dev/null || echo "No pods found"
	@kubectl get clusterissuer 2>/dev/null || echo "No ClusterIssuers found"
	@kubectl get certificate -A 2>/dev/null || echo "No certificates found"
	@kubectl get secret -A 2>/dev/null | grep -E "(tls|cert)" || echo "No TLS secrets found"
	@kubectl get ingress -A 2>/dev/null || echo "No ingress found"