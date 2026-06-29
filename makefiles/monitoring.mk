# ============================================
# monitoring.mk - Monitoring with Prometheus + Grafana
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
MONITORING_NAMESPACE ?= monitoring
PROMETHEUS_VERSION   ?= 25.8.0
GRAFANA_VERSION      ?= 8.7.0
GRAFANA_ADMIN_PASS   ?= admin
GRAFANA_PORT         ?= 3000

# ============================================
# Help
# ============================================
.PHONY: help-monitoring
help-monitoring:
	@echo "$(CYAN)Monitoring:$(RESET)"
	@echo "  monitoring-install   Install Prometheus + Grafana"
	@echo "  monitoring-uninstall Uninstall monitoring"
	@echo "  monitoring-status    Show monitoring status"
	@echo "  monitoring-port      Port-forward Grafana"

# ============================================
# Install Monitoring Stack
# ============================================

.PHONY: monitoring-install
monitoring-install: ## Install Prometheus + Grafana
	@echo "$(GREEN)📊 Installing monitoring stack...$(RESET)"
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update 2>/dev/null
	@helm repo update prometheus-community 2>/dev/null
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
		--namespace $(MONITORING_NAMESPACE) --create-namespace \
		--version $(PROMETHEUS_VERSION) \
		--set grafana.enabled=true \
		--set grafana.adminPassword=$(GRAFANA_ADMIN_PASS) \
		--wait --timeout 300s 2>/dev/null || true
	@echo "$(GREEN)✅ Monitoring stack installed$(RESET)"
	@echo "$(YELLOW)🔑 Grafana credentials: admin/$(GRAFANA_ADMIN_PASS)$(RESET)"
	@echo "$(YELLOW)🔗 Port-forward: kubectl -n $(MONITORING_NAMESPACE) port-forward svc/prometheus-grafana $(GRAFANA_PORT):80$(RESET)"

.PHONY: monitoring-uninstall
monitoring-uninstall: ## Uninstall monitoring
	@echo "$(RED)💥 Uninstalling monitoring...$(RESET)"
	@helm uninstall prometheus -n $(MONITORING_NAMESPACE) 2>/dev/null || true
	@kubectl delete namespace $(MONITORING_NAMESPACE) 2>/dev/null || true
	@echo "$(GREEN)✅ Monitoring uninstalled$(RESET)"

.PHONY: monitoring-status
monitoring-status: ## Show monitoring status
	@echo "$(YELLOW)📊 Monitoring status:$(RESET)"
	@kubectl -n $(MONITORING_NAMESPACE) get pods 2>/dev/null || echo "Monitoring not installed"

.PHONY: monitoring-port
monitoring-port: ## Port-forward Grafana
	@echo "$(YELLOW)🔗 Port-forwarding Grafana to $(GRAFANA_PORT)...$(RESET)"
	@kubectl -n $(MONITORING_NAMESPACE) port-forward svc/prometheus-grafana $(GRAFANA_PORT):80
