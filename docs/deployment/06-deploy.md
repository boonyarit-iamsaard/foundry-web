# Deploy

Use zero-downtime deploys by default. Use the maintenance-mode variant only when you need a simpler path or the release includes risky operational work that cannot stay live during preparation.

## Pre-Deployment Checklist

- Database backup taken if migrations may be risky.
- Pending migrations reviewed for backward compatibility.
- `shared/.env` updated if configuration changed.
- CI and tests are green.

## Preferred Path: Zero-Downtime Deploy

This matches `scripts/deploy.sh`.

### 1. Create the release

```bash
RELEASE="$(date +%Y%m%d%H%M%S)"
RELEASE_PATH="/var/www/<APP_NAME>/releases/${RELEASE}"

git clone --depth=1 <REPO_URL> "$RELEASE_PATH"
cd "$RELEASE_PATH"
```

### 2. Link shared resources

```bash
rm -rf "$RELEASE_PATH/storage"
ln -sf /var/www/<APP_NAME>/shared/storage "$RELEASE_PATH/storage"
mkdir -p "$RELEASE_PATH/bootstrap/cache"
ln -sf /var/www/<APP_NAME>/shared/.env "$RELEASE_PATH/.env"
```

### 3. Install dependencies and build assets

```bash
composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist
pnpm install --frozen-lockfile
pnpm run build
```

### 4. Warm caches and create public storage link

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan storage:link
```

### 5. Run backward-compatible migrations

```bash
php artisan migrate --force
```

Destructive schema changes should be split across multiple releases.

### 6. Set permissions

```bash
find "$RELEASE_PATH" -type f -exec chmod 644 {} \;
find "$RELEASE_PATH" -type d -exec chmod 755 {} \;
chmod -R 775 "$RELEASE_PATH/bootstrap/cache"
chmod -R 775 /var/www/<APP_NAME>/shared/storage
chmod 600 /var/www/<APP_NAME>/shared/.env
```

### 7. Activate the release

```bash
ln -sfn "$RELEASE_PATH" /var/www/<APP_NAME>/current
sudo systemctl reload php<PHP_VERSION>-fpm
php /var/www/<APP_NAME>/current/artisan queue:restart
```

### 8. Prune old releases and verify

```bash
cd /var/www/<APP_NAME>/releases
for release in $(ls -1t | sed -n '6,$p'); do rm -rf -- "$release"; done

curl -I https://<DOMAIN>
php /var/www/<APP_NAME>/current/artisan --version
sudo supervisorctl status <APP_NAME>-worker:*
```

## Fallback Path: Maintenance-Mode Deploy

Use this when a brief maintenance window is acceptable.

```bash
php /var/www/<APP_NAME>/current/artisan down --secret="<BYPASS_SECRET>" --render="errors.503"
```

Prepare the release exactly as above, then:

```bash
ln -sfn "$RELEASE_PATH" /var/www/<APP_NAME>/current
sudo systemctl reload php<PHP_VERSION>-fpm
php /var/www/<APP_NAME>/current/artisan queue:restart
php /var/www/<APP_NAME>/current/artisan up
```

## Script Usage

After you configure `scripts/deploy.sh`, run:

```bash
./scripts/deploy.sh
```

## Verification

```bash
curl -I https://<DOMAIN>
readlink /var/www/<APP_NAME>/current
ls /var/www/<APP_NAME>/releases | wc -l
sudo supervisorctl status
```
