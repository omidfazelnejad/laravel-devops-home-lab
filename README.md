# Laravel DevOps Home Lab (Infrastructure as Code)

Production-like DevOps and Linux System Administration home lab built to containerize, automate, harden, and operate a real-world Laravel workload migrated from legacy cPanel hosting (`cpmove`).

> **Repository Scope (Infra-Only Architecture):**
> Following real-world DevOps separation of concerns, this public repository contains **only Infrastructure-as-Code (IaC), operational scripts, sanitized templates, and documentation**. Application source code (`app/`), production database dumps (`database-dump/`), backups (`backups/`), and secrets (`.env`, `ansible/group_vars/all.yml`, `ansible/group_vars/vault.yml`, `ansible/.vault_pass`) are intentionally excluded via `.gitignore`.

---

## Architecture Overview

~~~text
Browser / Client (Host)
   │ HTTP :8080
   ▼
Nginx (nginx:alpine — laravel-lab-nginx)
   │ FastCGI :9000 (Internal Compose Bridge Network)
   ▼
PHP-FPM 8.2 (custom image — laravel-lab-php:8.2)
   │ TCP :3306 (Internal only — NOT published to host)
   ▼
MariaDB 10.11.11 (laravel-lab-mysql) ──► Named Volume (db-data)
~~~

---

## Key Engineering Highlights

* **Containerization & Compose Orchestration (`docker/`, `docker-compose.yml`):**
  * Custom PHP 8.2-FPM image (`docker/php/Dockerfile`) with required extensions (`pdo_mysql`, `bcmath`, `gd`, `zip`, `exif`) and Composer.
  * MariaDB 10.11.11 with native `healthcheck` (`service_healthy` dependency gating), WSL2 InnoDB AIO fix (`--innodb-use-native-aio=0`), and zero host port exposure.
  * Container log rotation enforced via `json-file` driver (`max-size: 10m`, `max-file: 3`).
* **Linux System Administration & Operations (`scripts/`):**
  * `scripts/backup-db.sh` & `scripts/restore-db.sh`: Automated compressed database backup (`mariadb-dump` + `gzip`) with integrity verification and disaster recovery workflow.
  * `scripts/healthcheck.sh`: 12-point non-blocking Bash healthcheck verifying disk space, inodes, filesystem R/W, RAM, Docker daemon, Compose services, MariaDB health/query/capacity, and HTTP 200/302 status.
  * Host-level `logrotate` with `copytruncate` and `su root www-data` to safely rotate Laravel logs without breaking container file descriptors.
  * Least-privilege shared permissions using **SGID (`2775`)** on directories, **`0664`** on files, and **POSIX Default ACLs** to override PHP-FPM `umask`.
* **Configuration Management (`ansible/`):**
  * Modular, strictly idempotent (`changed=0` on re-runs) Ansible roles: `common`, `docker`, and `laravel_deploy`.
  * AES256-encrypted secret management via **Ansible Vault** with sanitized `.example` templates for reproducible onboarding.
* **Incident Response & Root Cause Analysis (RCA):**
  * `INC-2026-MIGRATION-02`: Diagnosed HTTP 500 caused by internal Docker DNS mismatch (`DB_HOST`) via Laravel logs and `getent hosts`.
  * `INC-2026-ANSIBLE-01`: Resolved a two-layer deployment failure involving `.env` file permissions (`0600` blocking `www-data`) and Ansible role-level `vars/` precedence overriding `group_vars/`.

---

## Quick Start (Reproducing the Infrastructure)

1. **Clone the repository:**
~~~bash
git clone git@github.com:omidfazelnejad/laravel-devops-home-lab.git
cd laravel-devops-home-lab
~~~

2. **Prepare environment & Ansible variable templates:**
~~~bash
cp .env.example .env
cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml
cp ansible/group_vars/vault.yml.example ansible/group_vars/vault.yml
~~~
Update the placeholder values and encrypt `ansible/group_vars/vault.yml` with `ansible-vault encrypt`.

3. **Place your Laravel application** inside `app/` (and optional initial SQL dump inside `database-dump/`).

4. **Provision & deploy with Ansible:**
~~~bash
cd ansible && ansible-playbook playbooks/site.yml
~~~

5. **Verify stack health:**
~~~bash
./scripts/healthcheck.sh
~~~

---

## Repository Structure

~~~text
.
├── ansible/                  # Idempotent roles (common, docker, laravel_deploy) & Vault templates
├── docker/                   # Custom PHP-FPM Dockerfile & Nginx reverse proxy config
├── scripts/                  # Operational Bash scripts (backup, restore, healthcheck)
├── docker-compose.yml        # Declarative service orchestration
├── .env.example              # Sanitized Docker Compose environment template
├── .gitignore                # Strict exclusion of secrets, app workload, dumps & backups
└── PROJECT_STATE.md          # Living engineering log and phase tracker
~~~
