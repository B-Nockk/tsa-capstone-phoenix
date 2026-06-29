# ============================================
# ansible.mk - Ansible Configuration
# ============================================

# ============================================
# Variables (overridable via env)
# ============================================
ANSIBLE_DIR      ?= $(INFRA_DIR)/ansible
ANSIBLE_INV      ?= $(ANSIBLE_DIR)/inventory/$(ENV)/hosts.ini
ANSIBLE_PLAYBOOK ?= $(ANSIBLE_DIR)/playbooks/site.yml
ANSIBLE_VERBOSE  ?=
ANSIBLE_USER     ?= ubuntu
ANSIBLE_SSH_ARGS ?= -o StrictHostKeyChecking=no

# ============================================
# Help
# ============================================
.PHONY: help-ansible
help-ansible:
	@echo "$(CYAN)Ansible:$(RESET)"
	@echo "  ansible-check       Check Ansible inventory"
	@echo "  ansible-ping        Ping all nodes"
	@echo "  ansible-run         Run main playbook"
	@echo "  ansible-server-only Run server-only playbook"
	@echo "  ansible-agent-only  Run agent-only playbook"
	@echo "  ansible-update      Update nodes (alias for ansible-run)"

# ============================================
# Ansible Commands
# ============================================

.PHONY: ansible-check
ansible-check: ## Check Ansible inventory
	@echo "$(YELLOW)🔍 Checking Ansible inventory...$(RESET)"
	@test -f $(ANSIBLE_INV) || { \
		echo "$(RED)❌ Inventory not found: $(ANSIBLE_INV)$(RESET)"; \
		echo "$(YELLOW)Run 'make infra-apply' first to generate inventory$(RESET)"; \
		exit 1; \
	}
	@echo "$(GREEN)✅ Inventory found$(RESET)"

.PHONY: ansible-ping
ansible-ping: ansible-check ## Ping all nodes
	@echo "$(YELLOW)📡 Pinging nodes...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible -i $(ANSIBLE_INV) -m ping all \
		--user=$(ANSIBLE_USER) --ssh-extra-args='$(ANSIBLE_SSH_ARGS)' $(ANSIBLE_VERBOSE)

.PHONY: ansible-run
ansible-run: ansible-check ## Run main playbook
	@echo "$(GREEN)⚙️  Running Ansible playbook...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(ANSIBLE_INV) $(ANSIBLE_PLAYBOOK) \
		--user=$(ANSIBLE_USER) --ssh-extra-args='$(ANSIBLE_SSH_ARGS)' $(ANSIBLE_VERBOSE)
	@echo "$(GREEN)✅ Ansible playbook complete$(RESET)"

.PHONY: ansible-server-only
ansible-server-only: ansible-check ## Run server-only playbook
	@echo "$(YELLOW)⚙️  Running server-only playbook...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(ANSIBLE_INV) playbooks/k3s-server.yml \
		--user=$(ANSIBLE_USER) --ssh-extra-args='$(ANSIBLE_SSH_ARGS)' $(ANSIBLE_VERBOSE)

.PHONY: ansible-agent-only
ansible-agent-only: ansible-check ## Run agent-only playbook
	@echo "$(YELLOW)⚙️  Running agent-only playbook...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook -i $(ANSIBLE_INV) playbooks/k3s-agent.yml \
		--user=$(ANSIBLE_USER) --ssh-extra-args='$(ANSIBLE_SSH_ARGS)' $(ANSIBLE_VERBOSE)

.PHONY: ansible-update
ansible-update: ansible-run ## Update nodes (alias for ansible-run)
	@echo "$(GREEN)✅ Ansible update complete$(RESET)"