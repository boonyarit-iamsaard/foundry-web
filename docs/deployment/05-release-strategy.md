# Release Strategy

The deployment model is release-based. Every deployment creates a timestamped release directory, links shared state into it, warms the app, and then swaps `current` atomically.

## Directory Layout

```text
/var/www/<APP_NAME>/
├── current -> releases/20250101120000/
├── releases/
│   ├── 20250101120000/
│   ├── 20250115090000/
│   └── 20250201143000/
├── shared/
│   ├── .env
│   ├── storage/
│   │   ├── app/public/
│   │   ├── framework/{cache,sessions,views}
│   │   └── logs/
└── backups/
```

## Rules

- `shared/.env` persists across releases.
- `shared/storage` persists across releases.
- `bootstrap/cache` stays local to each release.
- `current` is the only path Nginx, PHP-FPM, cron, and Supervisor should depend on.
- The symlink swap is atomic with `ln -sfn`.

## Retention Policy

- Keep the last 5 releases by default.
- Prune older releases at the end of each successful deploy.
- Keep enough history to make rollback instant.

## Scripts

Use these checked-in templates:

- `scripts/deploy.sh`
- `scripts/rollback.sh`
- `scripts/backup-db.sh`

They assume the release layout described above and should be configured before first use.

## Verification

```bash
ls -la /var/www/<APP_NAME>/
ls -la /var/www/<APP_NAME>/current/storage
readlink /var/www/<APP_NAME>/current
```
