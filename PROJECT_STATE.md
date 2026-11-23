# Laravel DevOps Home Lab — Project State

## Current Phase
Phase 5 — Ansible & Configuration Management — Completed

Current Step:
Phase 5 completed, audited for strict idempotency (`changed=0`), and verified via multi-layer incident simulation (`INC-2026-ANSIBLE-01`). Ready to transition to Phase 6 (Git, GitHub Workflow & Security/Sanitization).

## Completed Work

### Phase 0 & 1 — Discovery & Initial Dockerization
- Analyzed real-world cPanel migration workload (`cpmove`) following the *Discovery First* principle.
- Verified base request lifecycle: Browser -> Nginx -> PHP-FPM -> Database.

### Phase 2 & 2.5 — Docker Compose & Troubleshooting Simulation
- Configured declarative `docker-compose.yml` for Nginx, custom PHP 8.2-FPM (`laravel-lab-php:8.2`), and MariaDB 10.11.11.
- Implemented automated `.sql` dump import via `/docker-entrypoint-initdb.d/`.
- Resolved MariaDB InnoDB crash in WSL2 via `--innodb-use-native-aio=0`.
- Diagnosed and resolved DNS resolution incident (`INC-2026-MIGRATION-02`).

### Phase 3 — Database Operations, Backup & Disaster Recovery
- Configured native container healthcheck on MariaDB (`service_healthy`).
- Developed `scripts/backup-db.sh` (atomic dump, `gzip` streaming, integrity verification, retention) and `scripts/restore-db.sh`.
- Verified full Disaster Recovery simulation (database drop and 32-table restore).

### Phase 4 — Linux System Administration & Host Operations
- Audited host processes, memory usage, disk blocks/inodes, and network sockets (`ss -tulpn`).
- Configured Docker `json-file` logging limits (`max-size: 10m`, `max-file: 3`).
- Implemented SGID (`2775`) directory permissions and `0664` file permissions on Laravel writable paths.
- Configured host `logrotate` (`/etc/logrotate.d/laravel-lab`) with `copytruncate` to rotate a 73MB active `laravel.log`.
- Built and chaos-tested a 12-point non-blocking `scripts/healthcheck.sh` across 4 failure scenarios (`Exit code: 1` verified).

### Phase 5 — Ansible & Configuration Management
- Installed `ansible-core` and structured `ansible/` with `ansible.cfg`, `inventory/hosts.ini` (`connection: local` for WSL2), `group_vars/`, `playbooks/site.yml`, and modular roles.
- **Role `common`:** Automated OS packages (`apt` with `cache_valid_time: 3600`), `cron` service, `www-data` group membership, operational directories/script permissions (`0755`), Jinja2 `logrotate` template, nightly DB backup cronjob, SGID (`2775`) + `0664` file separation, and **POSIX Default ACL** (`ansible.posix.acl`) on writable subdirectories to override PHP-FPM `umask` (`0022`) and guarantee strict idempotency.
- **Role `docker`:** Automated `docker` group membership, `/etc/docker/daemon.json` log limits via Jinja2 template, WSL2-safe `Restart Docker` **Handler** (`notify`), and Docker Compose v2 verification.
- **Role `laravel_deploy` & Ansible Vault:** Separated public config (`group_vars/all.yml`) from AES256-encrypted secrets (`group_vars/vault.yml`) with a gitignored `.vault_pass` (`0600`). Automated secure `.env` rendering (`0600` for root Compose `.env`, `0640` for Laravel `.env`), `docker compose up -d`, and post-deploy verification via `healthcheck.sh`.
- **Incident Resolved (`INC-2026-ANSIBLE-01` — Multi-Layer Deployment Failure):**
  - *Layer 1 (Silent `.env` Permission Denied):* Diagnosed HTTP 500 (`production.ERROR` + `Connection refused` to `127.0.0.1`) caused by `0600` mode on `app/sit3/.env` blocking `www-data`. Fixed in Ansible role tasks (`0640`) to prevent configuration drift.
  - *Layer 2 (Ansible Variable Precedence Override):* Diagnosed subsequent HTTP 500 (`local.ERROR` + `getaddrinfo for mysql-staging failed`) caused by `roles/laravel_deploy/vars/main.yml` overriding `group_vars/all.yml`. Removed role-level env override, previewed fix via `--check --diff`, and verified recovery.
- **Verification:** Confirmed full stack provisioning and strict idempotency across 22 tasks (`ok=22, changed=0, failed=0`).

## Current Architecture
- **Ingress:** Nginx (`laravel-lab-nginx`) on Host Port `8080`
- **Application:** PHP-FPM 8.2 (`laravel-lab-php:8.2`) with SGID + POSIX Default ACL shared storage
- **Database:** MariaDB 10.11.11 (`laravel-lab-mysql`) on isolated internal Compose bridge network
- **Configuration Management & Automation:** Ansible (`common`, `docker`, `laravel_deploy` roles + Ansible Vault), `backup-db.sh`, `restore-db.sh`, `healthcheck.sh` (12 checks), and host `logrotate`

## Known Issues / Pending Hardening
- Repository is not yet initialized/sanitized for public GitHub portfolio publication (contains real cPanel backup files and local runtime artifacts that must be audited/sanitized before push).
- Session/cache drivers remain `file` for local lab parity (production architecture would offload state to Redis/S3 and ship logs to `stderr`).

## Next Step
Phase 6 — Git, GitHub Workflow, Secret Auditing & Repository Sanitization.
