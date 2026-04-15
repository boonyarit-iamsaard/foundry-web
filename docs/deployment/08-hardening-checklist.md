# Hardening Checklist

Run this checklist before go-live and after major infrastructure changes.

## Security

- [ ] SSH password authentication disabled.
- [ ] Root SSH login disabled.
- [ ] UFW active with only 22, 80, and 443 open.
- [ ] Fail2Ban active with `maxretry=3`.
- [ ] `APP_DEBUG=false` in production.
- [ ] `APP_ENV=production` confirmed.
- [ ] `shared/.env` permissions set to `600`.
- [ ] `expose_php = Off`.
- [ ] `server_tokens off` in Nginx.
- [ ] Hidden files blocked by Nginx.
- [ ] Database user has only required privileges.
- [ ] Redis is bound to localhost only.

## Application

- [ ] `config:cache` run.
- [ ] `route:cache` run.
- [ ] `view:cache` run.
- [ ] `event:cache` run.
- [ ] OPcache enabled.
- [ ] `shared/storage` and `bootstrap/cache` writable by the PHP-FPM user.
- [ ] `public/storage` symlink exists.
- [ ] Queue workers run as the deploy user.
- [ ] Scheduler cron entry confirmed.

## SSL and Reliability

- [ ] Certificate valid and auto-renewal configured.
- [ ] HSTS header present.
- [ ] HTTP redirects to HTTPS.
- [ ] Supervisor has `autorestart=true`.
- [ ] Swap is configured on small hosts.
- [ ] Log rotation is configured.
- [ ] Automated database backups are scheduled.
- [ ] External uptime or health monitoring exists.

## Log Rotation

```bash
sudo nano /etc/logrotate.d/<APP_NAME>
```

```text
/var/www/<APP_NAME>/shared/storage/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 <DEPLOY_USER> www-data
    sharedscripts
    postrotate
        /usr/bin/php /var/www/<APP_NAME>/current/artisan queue:restart > /dev/null 2>&1 || true
    endscript
}
```

Test it:

```bash
sudo logrotate --debug /etc/logrotate.d/<APP_NAME>
```

## Automated Database Backup

Configure `scripts/backup-db.sh`, then schedule it:

```cron
0 2 * * * /home/<DEPLOY_USER>/scripts/backup-db.sh >> /var/www/<APP_NAME>/shared/storage/logs/backup-db.log 2>&1
```

## Health Check

Laravel exposes `/up` by default on modern versions. Confirm it exists before adding a custom endpoint.
