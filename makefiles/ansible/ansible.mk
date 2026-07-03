# ============================================
# ansible.mk - Ansible Configuration
# ============================================
ANSIBLE_DIR      	?= $(INFRA_DIR)/ansible
ANSIBLE_INV      	?= $(ANSIBLE_DIR)/inventory/$(ENV)/hosts.ini
ANSIBLE_PLAYBOOK 	?= $(ANSIBLE_DIR)/playbooks/site.yml
ANSIBLE_USER		?= ubuntu
INSTALL_DOCKER		?= false

# 🤖 Smart Environment Detection:
# GitHub Actions automatically sets GITHUB_ACTIONS=true in the runner environment
ifeq ($(GITHUB_ACTIONS),true)
    ANSIBLE_SSH_KEY ?= $(HOME)/.ssh/id_ed25519
else
    ANSIBLE_SSH_KEY ?= $(HOME)/.ssh/tsa-capstone/tsa-capstone-project
endif

ANSIBLE_SSH_ARGS ?= -o StrictHostKeyChecking=no -o IdentitiesOnly=yes

# 🎯 Force Precedence: Extra Vars (-e) completely override internal inventory host variables
ANSIBLE_OPTS     ?= -e "ansible_ssh_private_key_file=$(ANSIBLE_SSH_KEY)"

.PHONY: help-ansible
help-ansible:
	@echo "$(CYAN)Ansible:$(RESET)"
	@echo "  ans-check           Check Ansible inventory"
	@echo "  ans-ping            Ping all nodes"
	@echo "  ans-run             Run main playbook"

.PHONY: ans-check
ans-check: ## Check Ansible inventory
	@test -f $(ANSIBLE_INV) || { echo "$(RED)❌ Inventory not found at $(ANSIBLE_INV)$(RESET)"; exit 1; }
	@echo "$(GREEN)✅ Inventory found$(RESET)"

.PHONY: ans-ping
ans-ping: ans-check ## Ping all nodes
	@cd $(ANSIBLE_DIR) && ansible -i inventory/$(ENV)/hosts.ini -m ping all \
		--user=$(ANSIBLE_USER) \
		--ssh-extra-args='$(ANSIBLE_SSH_ARGS)' \
		$(ANSIBLE_OPTS)

.PHONY: ans-run
ans-run: ans-check ## Run main playbook
	@cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(ENV)/hosts.ini playbooks/site.yml \
		-e "install_docker=$(INSTALL_DOCKER) env=$(ENV)" \
		--user=$(ANSIBLE_USER) \
		--ssh-extra-args='$(ANSIBLE_SSH_ARGS)' \
		$(ANSIBLE_OPTS)

.PHONY: ans-server-only
ans-server-only: ans-check ## Run server-only playbook
	@cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(ENV)/hosts.ini playbooks/k3s-server.yml \
		--user=$(ANSIBLE_USER) \
		--ssh-extra-args='$(ANSIBLE_SSH_ARGS)' \
		$(ANSIBLE_OPTS)

.PHONY: ans-agent-only
ans-agent-only: ans-check ## Run agent-only playbook
	@cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/$(ENV)/hosts.ini playbooks/k3s-agent.yml \
		--user=$(ANSIBLE_USER) \
		--ssh-extra-args='$(ANSIBLE_SSH_ARGS)' \
		$(ANSIBLE_OPTS)
