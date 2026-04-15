# Deployment Handbook

This directory replaces the old single-file VPS SOP with focused runbooks arranged by operator workflow.

## Recommended Path

1. Read [01-overview-and-inputs.md](01-overview-and-inputs.md).
2. Provision the host with [02-server-provisioning.md](02-server-provisioning.md).
3. Bootstrap PostgreSQL and the first release with [03-database-and-bootstrap.md](03-database-and-bootstrap.md).
4. Configure Nginx, workers, scheduler, and TLS with [04-web-queue-and-ssl.md](04-web-queue-and-ssl.md).
5. Understand the release layout in [05-release-strategy.md](05-release-strategy.md).
6. Use [06-deploy.md](06-deploy.md) for repeatable releases.
7. Use [07-rollback.md](07-rollback.md) during incidents.
8. Use [08-hardening-checklist.md](08-hardening-checklist.md) before go-live and after infra changes.
9. Use [09-troubleshooting.md](09-troubleshooting.md) for operational failures.

## Advanced Guides

- [advanced/blue-green.md](advanced/blue-green.md): optional traffic-switching workflow.
- [advanced/github-actions.md](advanced/github-actions.md): optional CI/CD integration.

## Scripts

The shell appendix has been extracted into `scripts/`:

- `scripts/provision.sh`
- `scripts/deploy.sh`
- `scripts/rollback.sh`
- `scripts/backup-db.sh`

These are runnable templates. Update the configuration blocks before using them on a real server.
