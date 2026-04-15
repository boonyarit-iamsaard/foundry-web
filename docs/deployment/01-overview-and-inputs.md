# Overview and Inputs

## Purpose

This handbook defines a repeatable operating model for provisioning a Ubuntu LTS VPS, deploying a Laravel application, and managing repeat releases on a single host.

## Scope

- In scope: initial provisioning, dependency installation, PostgreSQL setup, first bootstrap, repeat deployments, rollback, hardening, troubleshooting, and optional CI/CD.
- Out of scope: Kubernetes, multi-region topologies, managed databases, and containerized deployment platforms.
- Baseline: one Laravel application on one Ubuntu VPS.

## Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS VPS with confirmed root SSH access.
- Domain DNS A record already points to the server IP.
- Git repository URL for the application.
- Local machine has `ssh-keygen`.
- SSH key pair exists locally.
- Production `.env` values are ready.
- PostgreSQL is the selected production database.

## Shared Inputs

Substitute these placeholders consistently across all runbooks and scripts:

| Variable      | Description           | Example                        |
| ------------- | --------------------- | ------------------------------ |
| `SERVER_IP`   | VPS public IP address | `203.0.113.10`                 |
| `DEPLOY_USER` | Non-root sudo user    | `deployer`                     |
| `DOMAIN`      | Primary domain        | `example.com`                  |
| `APP_NAME`    | Application slug      | `myapp`                        |
| `REPO_URL`    | Git repository URL    | `git@github.com:org/myapp.git` |
| `PHP_VERSION` | PHP version           | `8.4`                          |
| `DB_ENGINE`   | Database engine       | `pgsql`                        |
| `DB_NAME`     | Database name         | `myapp_production`             |
| `DB_USER`     | Database user         | `myapp_db`                     |
| `DB_PASSWORD` | Database password     | generated secret               |
| `DEPLOY_PATH` | Release root          | `/var/www/myapp`               |
| `APP_ENV`     | Laravel environment   | `production`                   |

## Expected Outputs

- Hardened Ubuntu VPS with non-root access.
- PHP-FPM, Nginx, Redis, PostgreSQL, Supervisor, and cron in place.
- Shared release layout with `current`, `releases`, `shared`, and `backups`.
- Deploy and rollback procedures that do not require ad hoc commands.
- SSL and queue/scheduler operations configured.

## Operating Conventions

- Prefer the scripts in `scripts/` when they match the task.
- Treat zero-downtime deploys as the default release path.
- Take a database backup before risky migrations or rollback.
- Keep `shared/.env` and `shared/storage` outside release directories.
- Use the advanced docs only when the core single-host workflow is no longer enough.
