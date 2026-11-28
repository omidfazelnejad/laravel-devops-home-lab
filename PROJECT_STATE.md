# Laravel DevOps Home Lab — Project State

## Current Phase
Phase 6 — Git & GitHub Engineering Workflow — Completed

Current Step:
Phase 6 completed and audited (0 leaked secrets in full Git history). Repository published as a sanitized Infra-Only portfolio with Conventional Commits, Pull Requests, Merge Conflict Resolution, Revert/Reset drill, and annotated release tag `v1.0.0`. Ready to transition to Phase 7 (CI/CD with GitHub Actions).

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
- Structured `ansible/` with `ansible.cfg`, `inventory/hosts.ini` (`connection: local`), `group_vars/`, `playbooks/site.yml`, and modular roles (`common`, `docker`, `laravel_deploy`).
- Enforced strict idempotency (`ok=22, changed=0, failed=0`) including POSIX Default ACLs (`ansible.posix.acl`) to override PHP-FPM `umask`.
- Managed secrets with AES256-encrypted Ansible Vault and resolved two-layer incident `INC-2026-ANSIBLE-01` (`.env` permission `0600` vs `0640` and role-level `vars/` precedence override).

### Phase 6 — Git & GitHub Engineering Workflow
- **Infra-Only Repository Architecture:** Separated Infrastructure-as-Code from private cPanel workload (`app/`), dumps (`database-dump/`), backups (`backups/`), and secrets (`.env`, `.vault_pass`, `all.yml`, `vault.yml`) via hardened `.gitignore`, `.gitkeep` placeholders, and sanitized `.example` templates.
- **Git Identity & SSH Auth:** Configured GitHub privacy-preserving `noreply` email and `Ed25519` SSH key authentication.
- **Conventional Commits & GitHub Flow:** Built layered atomic commit history, executed PR #1 (`docs/add-portfolio-readme` adding portfolio `README.md`), and resolved a real merge conflict locally on feature branch `docs/enhance-quickstart` before merging PR #2.
- **Recovery & Versioning:** Practiced isolated `git revert` vs `git reset --soft` recovery workflows, audited full Git commit history (0 leaked secrets/identifiers), and tagged `v1.0.0`.

## Current Architecture
- **Ingress:** Nginx (`laravel-lab-nginx`) on Host Port `8080`
- **Application:** PHP-FPM 8.2 (`laravel-lab-php:8.2`) with SGID + POSIX Default ACL shared storage
- **Database:** MariaDB 10.11.11 (`laravel-lab-mysql`) on isolated internal Compose bridge network
- **Configuration Management & Automation:** Ansible (`common`, `docker`, `laravel_deploy` + Vault), `backup-db.sh`, `restore-db.sh`, `healthcheck.sh` (12 checks), and host `logrotate`
- **Source Control:** Public Infra-Only GitHub repository (`omidfazelnejad/laravel-devops-home-lab`) with SSH auth, PR workflow, and `v1.0.0` release tag

## Known Issues / Pending Hardening
- Session/cache drivers remain `file` for local lab parity (production architecture would offload state to Redis/S3 and ship logs to `stderr`).
- Automated CI validation (linting Dockerfiles, Bash scripts, and Ansible playbooks on PRs) is not yet enabled (planned for Phase 7).

## Next Step
Phase 7 — CI/CD Engineering with GitHub Actions (Automated Linting, Validation & Security Checks).
