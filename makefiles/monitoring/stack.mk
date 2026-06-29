# ============================================
# monitoring/stack.mk - Monitoring Stack
# ============================================
MONITORING_NAMESPACE ?= monitoring
PROMETHEUS_VERSION   ?= 25.8.0
GRAFANA_ADMIN_PASS   ?= admin
GRAFANA_PORT         ?= 3000

.PHONY: help-monitoring
help-monitoring:
	@echo "$(CYAN)Monitoring:$(RESET)"
	@echo "  mon-install           Install Prometheus + Grafana"
	@echo "  mon-uninstall         Uninstall monitoring"
	@echo "  mon-status            Show monitoring status"
	@echo "  mon-port              Port-forward Grafana"

.PHONY: mon-install
mon-install: ## Install Prometheus + Grafana
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update 2>/dev/null
	@helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace $(MONITORING_NAMESPACE) --create-namespace --version $(PROMETHEUS_VERSION) --set grafana.enabled=true --set grafana.adminPassword=$(GRAFANA_ADMIN_PASS) --wait --timeout 300s 2>/dev/null || true

.PHONY: mon-uninstall
mon-uninstall: ## Uninstall monitoring
	@helm uninstall prometheus -n $(MONITORING_NAMESPACE) 2>/dev/null || true
	@kubectl delete namespace $(MONITORING_NAMESPACE) 2>/dev/null || true

.PHONY: mon-status
mon-status: ## Show monitoring status
	@kubectl -n $(MONITORING_NAMESPACE) get pods 2>/dev/null || echo "Monitoring not installed"

.PHONY: mon-port
mon-port: ## Port-forward Grafana
	@kubectl -n $(MONITORING_NAMESPACE) port-forward svc/prometheus-grafana $(GRAFANA_PORT):80