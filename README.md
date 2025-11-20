# platform-bootstrap

platform-bootstrap is an Ansible-based toolkit for provisioning Debian servers for self-hosted applications. It provides a repeatable, idempotent infrastructure-as-code foundation that can be applied consistently across staging and production environments.

It handles the full lifecycle of a fresh server, including:

- base system configuration and SSH access
- firewall and intrusion protection
- PostgreSQL setup
- application user + directories
- Caddy reverse proxy with HTTPS

The goal is to provide a simple, reusable starting point for deploying small applications without manually configuring servers each time.

## Features

- **Base server setup** — users, SSH, common packages, timezone, updates
- **PostgreSQL provisioning** — installation, users, databases
- **Firewall (UFW) + Fail2Ban** — basic hardening
- **Caddy reverse proxy** — domain routing and TLS
- **Environment-specific inventories** — stage vs prod
- **Idempotent roles** — safe to re-run
- **Encrypted secrets with Ansible Vault**

## Project Structure

```
platform-bootstrap/
├── ansible.cfg
├── inventories/
│ ├── stage/
│ └── prod/
├── roles/
│ ├── base/
│ ├── firewall/
│ ├── fail2ban/
│ ├── postgresql/
│ ├── app_server/
│ └── caddy/
└── playbooks/
├── base_setup.yml
├── db_setup.yml
├── app_setup.yml
└── site.yml
```

## Getting Started

Install the required Ansible collections:

```bash
ansible-galaxy collection install community.general community.postgresql
```

Set up your inventory (staging example):

```bash
vim inventories/stage/hosts.yml
```

Add your servers, grouped by role:

```yaml
db_servers:
  hosts:
    stage-db1:
      ansible_host: 10.2.0.5

app_servers:
  hosts:
    stage-app1:
      ansible_host: 10.2.0.10
```

### First Run

For initial provisioning of a fresh server (connecting as root):

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml \
  -u root \
  --ask-vault-pass \
  --ask-pass \
  --ask-become-pass
```

Subsequent runs (after SSH keys are configured and deployer user created):

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --ask-vault-pass
```

If you need encrypted variables, create vault files:

```bash
# Shared secrets (system user password)
ansible-vault create group_vars/all/vault.yml

# Stage database password
ansible-vault create inventories/stage/group_vars/vault.yml

# Production database password
ansible-vault create inventories/prod/group_vars/vault.yml
```

Then run the full playbook:

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --ask-vault-pass
```

To preview changes without applying them:

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --check
```

## Running Specific Roles

#### Base setup on all hosts

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/base_setup.yml
```

#### Database server only

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/db_setup.yml --ask-vault-pass
```

#### Application host only

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/app_setup.yml
```

#### Limit execution to specific hosts:

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --limit stage-app1
```

## Quick Commands

Use the Makefile for common operations:

```bash
make help          # Show all commands
make ping-stage    # Test connectivity
make setup-stage   # Full staging setup
make check-stage   # Dry-run
```

## Configuration

Some commonly used variables:

```yaml
# group_vars/all.yml
env: stage
timezone: Europe/Copenhagen
system_user: deployer
```

Database-specific variables:

```yaml
postgresql_databases:
  - name: appdb

postgresql_users:
  - name: app
    password: "{{ vault_db_password }}"
    database: appdb
```

Application role variables:

```yaml
app_name: myapp # Required - used for system user and directory paths
# app_user: custom_user  # Optional - defaults to app_name
caddy_config_source: stage_Caddyfile
```

Directories are automatically generated from `app_name`: `/opt/{{ app_name }}`, `/var/log/{{ app_name }}`, `/var/lib/{{ app_name }}`, `/etc/{{ app_name }}`
