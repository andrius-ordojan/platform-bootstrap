.PHONY: help ping-stage ping-prod setup-stage setup-prod base-stage base-prod db-stage db-prod app-stage app-prod check-stage check-prod

help:
	@echo "Platform Bootstrap - Ansible Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  ping-stage       - Test connection to staging servers"
	@echo "  ping-prod        - Test connection to production servers"
	@echo "  setup-stage      - Complete staging environment setup"
	@echo "  setup-prod       - Complete production environment setup"
	@echo "  base-stage       - Base configuration for staging"
	@echo "  base-prod        - Base configuration for production"
	@echo "  db-stage         - Database server setup for staging"
	@echo "  db-prod          - Database server setup for production"
	@echo "  app-stage        - App server setup for staging"
	@echo "  app-prod         - App server setup for production"
	@echo "  check-stage      - Dry-run for staging"
	@echo "  check-prod       - Dry-run for production"
	@echo ""

ping-stage:
	ansible all -i inventories/stage/hosts.yml -m ping

ping-prod:
	ansible all -i inventories/prod/hosts.yml -m ping

setup-stage:
	ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --ask-vault-pass

setup-prod:
	ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --ask-vault-pass

base-stage:
	ansible-playbook -i inventories/stage/hosts.yml playbooks/base_setup.yml

base-prod:
	ansible-playbook -i inventories/prod/hosts.yml playbooks/base_setup.yml

db-stage:
	ansible-playbook -i inventories/stage/hosts.yml playbooks/db_setup.yml --ask-vault-pass

db-prod:
	ansible-playbook -i inventories/prod/hosts.yml playbooks/db_setup.yml --ask-vault-pass

app-stage:
	ansible-playbook -i inventories/stage/hosts.yml playbooks/app_setup.yml

app-prod:
	ansible-playbook -i inventories/prod/hosts.yml playbooks/app_setup.yml

check-stage:
	ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --check --ask-vault-pass

check-prod:
	ansible-playbook -i inventories/prod/hosts.yml playbooks/site.yml --check --ask-vault-pass
