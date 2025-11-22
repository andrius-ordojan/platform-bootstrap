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
ansible-galaxy collection install community.general community.postgresql ansible.posix
```

Set up your inventory (staging example):

```bash
vim inventories/stage/hosts.yml
```

Add your servers, grouped by role:

```yaml
all:
  vars:
    ansible_user: deployer
    ansible_python_interpreter: /usr/bin/python3

  children:
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

For initial provisioning of a fresh server, ensure your SSH public key is added to root's `authorized_keys` during server creation.

Create a vault password file:

```bash
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
```

For the first run on new servers, override the user to connect as root:

```bash
# First run on all servers
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml -e "ansible_user=root"

# Or limit to specific new servers
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --limit stage-app1 -e "ansible_user=root"
```

This will update the server, install essential and accessory packages, configure timezone, install neovim, configure unattended upgrades, create the deployer user, configure SSH keys, and harden SSH access (disabling root login and password authentication).

### Subsequent Runs

After the deployer user is created, run without the override:

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml
```

### Adding New Servers

When adding new servers to an existing environment:

1. Add the server to your inventory
2. Run the playbook with `--limit` and `-e "ansible_user=root"`:
   ```bash
   ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --limit new-hostname -e "ansible_user=root"
   ```
3. Future runs will use the deployer user automatically

### Setting Up Vault Secrets

The project uses Ansible Vault to encrypt sensitive data. Vault files are organized using the directory structure pattern:

```
inventories/stage/group_vars/
└── all/
    ├── main.yml        # Regular variables (committed)
    └── vault.yml       # Encrypted secrets (committed, encrypted)
```

#### Environment-specific secrets

Create vault files for each environment (staging and production):

```bash
# Create directory structure
mkdir -p inventories/stage/group_vars/all
mkdir -p inventories/prod/group_vars/all

# Create staging vault
ansible-vault create inventories/stage/group_vars/all/vault.yml

# Create production vault
ansible-vault create inventories/prod/group_vars/all/vault.yml
```

Each vault file should contain both the deployer password and database password:

```yaml
---
vault_system_user_password: "hashed_password_here"
vault_db_password: "your_database_password"
```

**To generate a hashed password for the deployer user:**

```bash
mkpasswd --method=sha-512
# Enter your password when prompted, then copy the full hash (starts with $6$)
```

**Note:**
- The vault password is automatically read from `.vault_pass`, so you won't be prompted during playbook runs
- `vault_system_user_password` must be a hashed password (use `mkpasswd`)
- `vault_db_password` can be plain text (PostgreSQL handles its own hashing)

## Running Specific Roles

#### Base setup on all hosts

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/base_setup.yml
```

#### Database server only

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/db_setup.yml
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
