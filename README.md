# platform-bootstrap

An Ansible toolkit for provisioning Debian servers for self-hosted applications. Provides repeatable, idempotent infrastructure-as-code that works across staging and production environments.

## Features

- **Two-user security model** — separate ansible (automation) and admin (manual) users with bash and fish shells
- **Base hardening** — SSH key auth, UFW firewall, Fail2Ban intrusion detection
- **PostgreSQL** — automated database and user provisioning with performance tuning
- **Application isolation** — separate users for code ownership vs runtime execution
- **Caddy reverse proxy** — automatic HTTPS with Let's Encrypt
- **Environment separation** — distinct staging and production inventories
- **Encrypted secrets** — Ansible Vault for passwords and sensitive data
- **Idempotent** — safe to re-run without breaking existing setup

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
- **Shell**: fish (with aliases and environment configs)
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

## Key Concepts

**User separation:** `automation_user` defines the user to create on the server (ansible), while `ansible_user` is the connection user. For first runs, override with `-e "ansible_user=root"` to connect as root while still creating the ansible user.

**Application security:** The app runs as `app_user` (system user) with write access only to logs and data. The `admin_user` owns code and config files (read-only for the app). This isolation limits damage if the application is compromised.

**Directory structure:**
- `/opt/{{ app_name }}/` - Application code (owned by admin_user)
- `/var/log/{{ app_name }}/` - Log files (owned by app_user)
- `/var/lib/{{ app_name }}/` - Application data (owned by app_user)
- `/etc/{{ app_name }}/` - Configuration (owned by admin_user, group deploy)

Configuration lives in `inventories/{stage,prod}/group_vars/` - check the files there for available variables.
