# Rollback

Rollback is a release operation, not a debugging step. Always back up the database first, then switch code, then verify the site and workers.

## Backup Before Rollback

```bash
pg_dump -U <DB_USER> -h 127.0.0.1 <DB_NAME> | gzip \
  > /var/www/<APP_NAME>/backups/pre_rollback_$(date +%Y%m%d%H%M%S).sql.gz
```

## List and Inspect Releases

```bash
ls -1t /var/www/<APP_NAME>/releases/
readlink /var/www/<APP_NAME>/current
```

## Roll Back to the Previous Release

```bash
TARGET_RELEASE=$(ls -1t /var/www/<APP_NAME>/releases/ | sed -n '2p')
ln -sfn /var/www/<APP_NAME>/releases/${TARGET_RELEASE} /var/www/<APP_NAME>/current
sudo systemctl reload php<PHP_VERSION>-fpm
php /var/www/<APP_NAME>/current/artisan queue:restart
```

## Roll Back to a Specific Release

```bash
ln -sfn /var/www/<APP_NAME>/releases/<RELEASE_TIMESTAMP> /var/www/<APP_NAME>/current
sudo systemctl reload php<PHP_VERSION>-fpm
php /var/www/<APP_NAME>/current/artisan queue:restart
```

## Verify

```bash
php /var/www/<APP_NAME>/current/artisan --version
curl -I https://<DOMAIN>
readlink /var/www/<APP_NAME>/current
```

## Migration Rollback Caveat

Only run `migrate:rollback` when the migration is reversible and clearly the cause of the incident:

```bash
php /var/www/<APP_NAME>/current/artisan migrate:rollback --step=1
```

If the schema change was destructive, restore from backup instead of relying on migration rollback.

## Safe and Unsafe Rollbacks

| Situation                   | Safe to Rollback? | Notes                          |
| --------------------------- | ----------------- | ------------------------------ |
| Code-only change            | Yes               | Symlink swap only              |
| Additive migration          | Yes               | Old code ignores new structure |
| Destructive migration       | No                | Restore from backup            |
| Renamed migration           | No                | Restore from backup            |
| Queue payload format change | Partial           | In-flight jobs may fail        |

## Script Usage

```bash
./scripts/rollback.sh
./scripts/rollback.sh 20250415103000
```
