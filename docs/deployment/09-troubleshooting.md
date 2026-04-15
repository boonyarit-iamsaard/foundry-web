# Troubleshooting

Use this guide by symptom. Restore service first, then investigate the underlying cause.

## 502 Bad Gateway

Likely cause: PHP-FPM is down or the Nginx socket path does not match.

```bash
sudo systemctl status php<PHP_VERSION>-fpm
ls -la /run/php/
sudo tail -50 /var/log/nginx/<APP_NAME>_error.log
grep fastcgi_pass /etc/nginx/sites-available/<APP_NAME>
sudo systemctl restart php<PHP_VERSION>-fpm
```

## 500 Internal Server Error

Likely cause: permissions, stale config cache, missing `.env`, or missing `APP_KEY`.

```bash
tail -100 /var/www/<APP_NAME>/shared/storage/logs/laravel-*.log
ls -la /var/www/<APP_NAME>/current/.env
grep APP_KEY /var/www/<APP_NAME>/shared/.env
sudo chmod -R 775 /var/www/<APP_NAME>/shared/storage
sudo chmod -R 775 /var/www/<APP_NAME>/current/bootstrap/cache
sudo chown -R <DEPLOY_USER>:www-data /var/www/<APP_NAME>/shared/storage
php /var/www/<APP_NAME>/current/artisan config:clear
php /var/www/<APP_NAME>/current/artisan config:cache
```

## Failed Deployment

If a new release was activated but the app is broken, roll back immediately:

```bash
TARGET=$(ls -1t /var/www/<APP_NAME>/releases/ | sed -n '2p')
ln -sfn /var/www/<APP_NAME>/releases/${TARGET} /var/www/<APP_NAME>/current
sudo systemctl reload php<PHP_VERSION>-fpm
php /var/www/<APP_NAME>/current/artisan queue:restart
tail -50 /var/www/<APP_NAME>/shared/storage/logs/laravel-*.log
```

## Failed Migration

```bash
php /var/www/<APP_NAME>/current/artisan migrate:status
psql -U <DB_USER> -h 127.0.0.1 <DB_NAME> -c "SELECT * FROM migrations ORDER BY id DESC LIMIT 10;"
```

Do not re-run migrations blindly. Inspect the database state first.

## Queue Workers Not Processing Jobs

```bash
sudo supervisorctl status <APP_NAME>-worker:*
tail -100 /var/www/<APP_NAME>/shared/storage/logs/supervisor-worker.log
sudo supervisorctl restart <APP_NAME>-worker:*
php /var/www/<APP_NAME>/current/artisan queue:failed
php /var/www/<APP_NAME>/current/artisan queue:retry all
redis-cli ping
```

## SSL Renewal Failed

```bash
sudo certbot certificates
sudo certbot renew --force-renewal
sudo journalctl -u certbot.timer -n 50
sudo systemctl status certbot.timer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

## Disk Space Exhausted

```bash
df -h
du -sh /var/www/<APP_NAME>/shared/storage/logs/*
du -sh /var/www/<APP_NAME>/backups/*
du -sh /var/www/<APP_NAME>/releases/*
```

Prune aggressively only after confirming rollback requirements:

```bash
cd /var/www/<APP_NAME>/releases
for release in $(ls -1t | sed -n '4,$p'); do rm -rf -- "$release"; done
find /var/www/<APP_NAME>/shared/storage/logs -name "*.log" -mtime +7 -delete
find /var/www/<APP_NAME>/backups -name "*.sql.gz" -mtime +7 -delete
```

## Scheduler Not Running

```bash
crontab -l | grep schedule:run
cd /var/www/<APP_NAME>/current && php artisan schedule:run
php /var/www/<APP_NAME>/current/artisan schedule:list
sudo systemctl status cron
sudo systemctl restart cron
```

## Permission Drift After Deploy

```bash
find /var/www/<APP_NAME>/current -type f -exec chmod 644 {} \;
find /var/www/<APP_NAME>/current -type d -exec chmod 755 {} \;
chmod -R 775 /var/www/<APP_NAME>/shared/storage
chmod -R 775 /var/www/<APP_NAME>/current/bootstrap/cache
chmod 600 /var/www/<APP_NAME>/shared/.env
sudo -u <DEPLOY_USER> touch /var/www/<APP_NAME>/shared/storage/logs/test_write && echo "OK"
sudo -u <DEPLOY_USER> rm /var/www/<APP_NAME>/shared/storage/logs/test_write
```
