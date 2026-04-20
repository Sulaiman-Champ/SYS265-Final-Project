# SYS265 Final Project — DNS Degenerates

## Overview

This repository contains all automation scripts and Ansible playbooks used to build and manage the DNS Degenerates enterprise lab environment for SYS-265. The environment runs on a segmented `172.16.1.0/24` LAN behind a PFSense firewall and is built around the `degenerates.local` Active Directory domain. Scripts cover passwordless SSH authentication setup, Linux package and user management via Ansible, Active Directory user provisioning, and Prometheus monitoring deployment.

The repository is organized into two top-level directories:

- `passwordless_auth/` — Bash scripts that establish SSH key-based authentication between the Ansible controller and managed nodes.
- `ansible/` — Ansible inventory files and playbooks for Linux and Windows system management, organized into subdirectories by purpose.

---

## Environment Systems

| System | IP Address | Role |
|--------|------------|------|
| Docker | 172.16.1.5 | Dockerized CMS host (Ubuntu) |
| DHCP1 | 172.16.1.10 | Redundant DHCP — primary (Ubuntu) |
| DHCP2 | 172.16.1.11 | Redundant DHCP — secondary (Ubuntu) |
| DC1 | 172.16.1.12 | Domain Controller — degenerates.local |
| DC2 | 172.16.1.13 | Domain Controller — degenerates.local |
| Util | 172.16.1.15 | Domain-joined utility / Ansible node (Ubuntu) |

MGMT2 (Ubuntu) serves as the Ansible controller. Its IP is assigned outside the DHCP scope.

---

## Passwordless Authentication Scripts

These scripts are run once during initial environment setup to create the `deployer` service account and distribute SSH keys from the Ansible controller to all managed Linux nodes. They must be run in order: `deployer_config.sh` on each target first, then `keygen.sh` on the controller, then `push_pub_key.sh`.

### `deployer_config.sh`

**Systems:** Docker (172.16.1.5), DHCP1 (172.16.1.10), DHCP2 (172.16.1.11), Util (172.16.1.15)

Run as root on each target Ubuntu node before any Ansible automation. This script creates the `deployer` service account, adds it to the `sudo` group, writes a validated `NOPASSWD` sudoers entry so Ansible can run privileged tasks without a password prompt, and sets up the `.ssh` directory with correct ownership and permissions to receive the controller's public key.

### `keygen.sh`

**Systems:** MGMT2 (Ansible controller)

Run on the Ansible controller as the `deployer` user. Generates an Ed25519 SSH keypair at `/home/deployer/.ssh/id_ed25519` and sets correct permissions on the `.ssh` directory and `authorized_keys` file. The resulting public key is what `push_pub_key.sh` distributes to the managed nodes.

### `push_pub_key.sh`

**Systems:** MGMT2 (Ansible controller) → Docker, DHCP1, DHCP2, Util

Run from the Ansible controller after both `deployer_config.sh` and `keygen.sh` have completed. Accepts either a single IP address or a plain-text hosts file as its argument. For each target, it uses `ssh-copy-id` to push the controller's Ed25519 public key to the `deployer` account, then verifies the key actually works by opening a test SSH session. Prints a per-host success/failure summary on completion and exits non-zero if any host failed.

```bash
./push_pub_key.sh passwordless_auth/hosts
./push_pub_key.sh 172.16.1.15
```

### `passwordless_auth/hosts`

Inventory file listing the four Linux node IPs targeted by the passwordless auth setup: 172.16.1.5, 172.16.1.10, 172.16.1.11, and 172.16.1.15.

---

## Ansible — General Inventory

### `ansible/hosts`

Top-level Ansible inventory file. Defines two groups: `[linux]` containing all four managed Linux nodes, and `[windows]` containing DC1, DC2, and two additional Windows hosts (172.16.1.122, 172.16.1.123). Sets `ansible_shell_type=powershell` for all Windows targets.

---

## Ansible — Linux Installs

### `ansible/installs/hosts`

Inventory file for the installs playbooks. Defines `[linux]`, `[windows]`, an `[AptInstall]` group targeting Util (172.16.1.15), and a `[useradd]` group also targeting Util (172.16.1.15).

### `apt_install.yml`

**Systems:** Util (172.16.1.15)

Installs the `aribas` package on Ubuntu hosts in the `[AptInstall]` group using the `apt` module with cache update. After installation, verifies the binary is accessible in `PATH` and fails with a clear message if it is not found.

### `add_user.yml`

**Systems:** Util (172.16.1.15)

Creates a standard Linux user account named `joesepher` on hosts in the `[useradd]` group. The password is hashed at runtime using SHA-512 to avoid plain-text storage. After creation, runs `id` to confirm the account exists and asserts success, failing early if the user is not found.

---

## Ansible — Prometheus Monitoring

### `ansible/prometheus/hosts`

Inventory file for Prometheus playbooks. Defines `[linux]`, `[windows]`, and a `[prometheus_targets]` group that maps the hostname `prometheus-host` to Util at 172.16.1.15.

### `install.sh`

**Systems:** MGMT2 (Ansible controller)

A short bootstrap script run on the controller before executing any Prometheus playbooks. Installs the `prometheus.prometheus` Ansible Galaxy collection, which provides the `node_exporter` and `prometheus` roles used by the playbooks below.

```bash
sudo bash ansible/prometheus/install.sh
```

### `node_maker.yml`

**Systems:** Docker (172.16.1.5), DHCP1 (172.16.1.10), DHCP2 (172.16.1.11), Util (172.16.1.15)

Deploys and enables the Prometheus `node_exporter` service on every host in the `[linux]` group using the `prometheus.prometheus.node_exporter` role. Ensures the service is started and set to start on boot. This exposes system metrics on port 9100 for scraping by Prometheus.

### `prom.yml`

**Systems:** Util (172.16.1.15) as Prometheus server; all `[linux]` nodes as scrape targets

The primary Prometheus deployment playbook. Runs against `[prometheus_targets]` (Util at 172.16.1.15) and performs the following:

- Installs prerequisite packages (`curl`, `tar`, `apt-transport-https`).
- Deploys both `node_exporter` (port 9100) and `prometheus` (port 9090) using Galaxy roles.
- Waits for both services to pass health checks before continuing.
- Appends all `[linux]` group hosts as additional scrape targets under the `node` job in `/etc/prometheus/prometheus.yml` using a templated `blockinfile` task.

### `test2.yml`

**Systems:** MGMT2 (Ansible controller, localhost), Util (172.16.1.15)

An alternative Prometheus deployment playbook used for testing collection resolution. Installs the `prometheus.prometheus` Galaxy collection on the controller via `localhost` connection, then deploys Prometheus on `[prometheus_targets]` using the fully-qualified role name (`prometheus.prometheus.prometheus`) to bypass Ansible collection lookup issues.

---

## Ansible — Windows / Active Directory

### `ansible/windows/hosts`

Inventory file for Windows playbooks. Defines `[linux]`, `[AptInstall]`, `[useradd]`, `[DomainControllers]` (DC1 at 172.16.1.12 only), and `[windows]` groups. All Windows groups use `ansible_shell_type=powershell`.

### `dom_user.yml`

**Systems:** DC1 (172.16.1.12) via the `[DomainControllers]` group

Creates a new user account in the `degenerates.local` Active Directory domain. Connects to the target domain controller using the `dadeployer` remote user and runs a PowerShell `New-ADUser` command via the `ansible.windows.win_powershell` module. All user attributes — username, password, first name, last name, display name, description, and target domain controller — are defined as variables at the top of the playbook and must be updated before each run.

```bash
ansible-playbook -i ansible/windows/hosts ansible/windows/dom_user.yml -u USER@degenerates --ask-pass
```
