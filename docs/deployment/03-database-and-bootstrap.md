# Database and Bootstrap

Use this document after the host runtime is ready. It covers PostgreSQL creation, shared directory layout, the first release bootstrap, and initial app activation.

## PostgreSQL Setup

### Install PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo systemctl status postgresql
```

### Create the application database and user

```bash
sudo -u postgres psql
```

```sql
CREATE USER <DB_USER> WITH PASSWORD '<DB_PASSWORD>';
CREATE DATABASE <DB_NAME> OWNER <DB_USER>
  ENCODING 'UTF8'
  LC_COLLATE 'en_US.UTF-8'
  LC_CTYPE 'en_US.UTF-8';
GRANT ALL PRIVILEGES ON DATABASE <DB_NAME> TO <DB_USER>;
\q
```

### Restrict local authentication

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Add before broader rules:

```text
local   <DB_NAME>    <DB_USER>                                md5
host    <DB_NAME>    <DB_USER>    127.0.0.1/32               md5
```

```bash
sudo systemctl restart postgresql
```

### Verify connectivity

```bash
psql -U <DB_USER> -d <DB_NAME> -h 127.0.0.1 -c "SELECT current_database();"
```

## First Application Bootstrap

Run these steps as `<DEPLOY_USER>`.

### Create the shared release layout

```bash
sudo mkdir -p /var/www/<APP_NAME>/{releases,shared,backups}
sudo mkdir -p /var/www/<APP_NAME>/shared/storage
sudo mkdir -p /var/www/<APP_NAME>/shared/storage/{app,framework,logs}
sudo mkdir -p /var/www/<APP_NAME>/shared/storage/framework/{cache,sessions,views}
sudo mkdir -p /var/www/<APP_NAME>/shared/storage/app/public
sudo chown -R <DEPLOY_USER>:www-data /var/www/<APP_NAME>
sudo chmod -R 755 /var/www/<APP_NAME>
sudo chmod -R 775 /var/www/<APP_NAME>/shared/storage
```

### Create the shared `.env`

```bash
nano /var/www/<APP_NAME>/shared/.env
chmod 600 /var/www/<APP_NAME>/shared/.env
```

Baseline content:

```ini
APP_NAME="<APP_NAME>"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://<DOMAIN>

LOG_CHANNEL=daily
LOG_LEVEL=error
LOG_DEPRECATIONS_CHANNEL=null

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=<DB_NAME>
DB_USERNAME=<DB_USER>
DB_PASSWORD=<DB_PASSWORD>

CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### Prepare Git access for private repositories

```bash
ssh-keygen -t ed25519 -C "server-deploy" -f ~/.ssh/id_ed25519_github -N ""
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
```

```bash
chmod 600 ~/.ssh/config ~/.ssh/id_ed25519_github
chmod 644 ~/.ssh/id_ed25519_github.pub ~/.ssh/known_hosts
ssh -T git@github.com || true
```

### Clone the initial release

```bash
RELEASE_DIR="/var/www/<APP_NAME>/releases/$(date +%Y%m%d%H%M%S)"
git clone <REPO_URL> "$RELEASE_DIR"
cd "$RELEASE_DIR"
```

### Install application dependencies

```bash
composer install \
  --no-dev \
  --optimize-autoloader \
  --no-interaction \
  --prefer-dist
```

### Link `.env`, generate the app key, and link storage

```bash
ln -sf /var/www/<APP_NAME>/shared/.env "$RELEASE_DIR/.env"
php artisan key:generate --force
rm -rf "$RELEASE_DIR/storage"
ln -sf /var/www/<APP_NAME>/shared/storage "$RELEASE_DIR/storage"
mkdir -p "$RELEASE_DIR/bootstrap/cache"
php artisan storage:link
```

### Build frontend assets

```bash
pnpm install --frozen-lockfile
pnpm run build
```

### Take a pre-migration backup and run migrations

```bash
pg_dump -U <DB_USER> -h 127.0.0.1 <DB_NAME> | gzip > /var/www/<APP_NAME>/backups/pre_migration_$(date +%Y%m%d%H%M%S).sql.gz
php artisan migrate --force
```

### Warm caches and activate the first release

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
ln -sfn "$RELEASE_DIR" /var/www/<APP_NAME>/current
```

### Final permissions

```bash
find /var/www/<APP_NAME>/current -type f -exec chmod 644 {} \;
find /var/www/<APP_NAME>/current -type d -exec chmod 755 {} \;
chmod -R 775 /var/www/<APP_NAME>/shared/storage
chmod -R 775 /var/www/<APP_NAME>/current/bootstrap/cache
chmod 600 /var/www/<APP_NAME>/shared/.env
```

## Verification

```bash
sudo systemctl status postgresql
ls -la /var/www/<APP_NAME>/
ls -la /var/www/<APP_NAME>/current/storage
php /var/www/<APP_NAME>/current/artisan --version
grep APP_KEY /var/www/<APP_NAME>/shared/.env
```
