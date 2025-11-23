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

- **Two-user security model** — separate ansible (automation) and admin (manual) users
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

## User Management Model

This project creates two separate users for security and audit purposes:

### ansible user (automation)
- **Purpose**: Ansible automation only
- **Sudo**: Passwordless (required for automation)
- **SSH**: Key-based authentication only
- **Usage**: Never login manually, only used by Ansible

### admin user (manual operations)
- **Purpose**: Human administrators for manual server work
- **Sudo**: Password-required (more secure for manual operations)
- **SSH**: Key-based authentication only
- **Usage**: Your daily driver for server management

This separation ensures:
- Clear audit trail between automated and manual changes
- Security: compromised admin credentials still require sudo password
- Flexibility: multiple admins without touching automation user

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

For the first run on new servers, you **must** override `ansible_user=root` to connect as root. This creates both the ansible and admin users on the server:

```bash
# First run on all servers
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml -e "ansible_user=root"

# Or limit to specific new servers
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --limit stage-app1 -e "ansible_user=root"
```

**Important:** The `-e "ansible_user=root"` flag overrides the connection user to root for this run only. The playbook will still create a user named `ansible` (defined by `automation_user` in your inventory vars) for future automation tasks.

This first run will:
- Update the server and install packages
- Configure timezone, neovim, and unattended upgrades
- Create the **ansible user** (passwordless sudo) for Ansible automation
- Create the **admin user** (password-required sudo) for manual operations
- Configure SSH keys for both users
- Harden SSH access (disable root login and password authentication)

### Subsequent Runs

After both users are created, run without the override. The playbook will automatically connect as the **ansible user**:

```bash
ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml
```

The connection user defaults to `automation_user` (ansible), so no `-e` override is needed.

### Logging in as Admin

For manual server operations, SSH in as the admin user:

```bash
ssh admin@your-server-ip
```

You'll be prompted for your sudo password when running privileged commands.

### Adding New Servers

When adding new servers to an existing environment:

1. Add the server to your inventory
2. Run the playbook with `--limit` and `-e "ansible_user=root"`:
   ```bash
   ansible-playbook -i inventories/stage/hosts.yml playbooks/site.yml --limit new-hostname -e "ansible_user=root"
   ```
3. Future runs will use the ansible user automatically

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

Each vault file should contain passwords for the admin user and database:

```yaml
---
# Required: hashed password for admin user (for sudo)
vault_admin_user_password: "hashed_password_here"

# Required: database password (plain text)
vault_db_password: "your_database_password"
```

**To generate a hashed password for the admin user:**

```bash
mkpasswd --method=sha-512
# Enter your password when prompted, then copy the full hash (starts with $6$)
```

**Note:**
- The vault password is automatically read from `.vault_pass`, so you won't be prompted during playbook runs
- `vault_admin_user_password` must be a hashed password (use `mkpasswd`)
- `vault_db_password` can be plain text (PostgreSQL handles its own hashing)
- The **ansible user** uses SSH key authentication only (no password)
- The **admin user** requires password for sudo (for security)

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
# inventories/stage/group_vars/all/main.yml
env: stage
timezone: Europe/Berlin

# Ansible automation user (passwordless sudo)
ansible_user: ansible
ansible_user_ssh_key: "{{ lookup('file', lookup('env', 'HOME') + '/.ssh/id_ed25519.pub') }}"

# Admin user for manual operations (password-required sudo)
admin_user: admin
admin_user_ssh_key: "{{ lookup('file', lookup('env', 'HOME') + '/.ssh/id_ed25519.pub') }}"
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
