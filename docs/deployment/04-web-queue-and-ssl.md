# Web, Queue, and SSL

This document completes the production runtime around an already-bootstrapped application.

## Web Server Configuration

### Create a dedicated PHP-FPM pool

```bash
sudo cp /etc/php/<PHP_VERSION>/fpm/pool.d/www.conf \
  /etc/php/<PHP_VERSION>/fpm/pool.d/<APP_NAME>.conf
sudo nano /etc/php/<PHP_VERSION>/fpm/pool.d/<APP_NAME>.conf
```

Update:

```ini
[<APP_NAME>]
user = <DEPLOY_USER>
group = www-data
listen = /run/php/<PHP_VERSION>-fpm-<APP_NAME>.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
```

Disable the default pool if the host is dedicated to this app:

```bash
sudo mv /etc/php/<PHP_VERSION>/fpm/pool.d/www.conf \
  /etc/php/<PHP_VERSION>/fpm/pool.d/www.conf.disabled
sudo systemctl restart php<PHP_VERSION>-fpm
ls /run/php/
```

### Create the Nginx site

```bash
sudo nano /etc/nginx/sites-available/<APP_NAME>
```

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name <DOMAIN> www.<DOMAIN>;
    root /var/www/<APP_NAME>/current/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "no-referrer-when-downgrade";

    index index.php;
    charset utf-8;
    client_max_body_size 64M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/<PHP_VERSION>-fpm-<APP_NAME>.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
        fastcgi_read_timeout 60;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/<APP_NAME>_access.log;
    error_log /var/log/nginx/<APP_NAME>_error.log;
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/<APP_NAME> /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
curl -I http://<DOMAIN>
```

## Queue and Scheduler

### Configure Supervisor workers

```bash
sudo nano /etc/supervisor/conf.d/<APP_NAME>-worker.conf
```

```ini
[program:<APP_NAME>-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/<APP_NAME>/current/artisan queue:work redis \
  --sleep=3 \
  --tries=3 \
  --max-time=3600 \
  --queue=high,default,low
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=<DEPLOY_USER>
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/<APP_NAME>/shared/storage/logs/supervisor-worker.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=5
stopwaitsecs=3600
```

Load and verify:

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start <APP_NAME>-worker:*
sudo supervisorctl status
```

### Configure the scheduler

```bash
crontab -e
```

```cron
* * * * * cd /var/www/<APP_NAME>/current && php artisan schedule:run >> /dev/null 2>&1
```

Verify:

```bash
sudo supervisorctl status <APP_NAME>-worker:*
php /var/www/<APP_NAME>/current/artisan schedule:list
crontab -l
```

## SSL and Domain Setup

### Install Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Issue the certificate

```bash
sudo certbot --nginx \
  -d <DOMAIN> \
  -d www.<DOMAIN> \
  --non-interactive \
  --agree-tos \
  --email admin@<DOMAIN> \
  --redirect
```

### Add HTTPS security headers

After Certbot edits the site config, add these headers to the HTTPS server block:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

Also disable Nginx version disclosure:

```bash
sudo nano /etc/nginx/nginx.conf
```

Set `server_tokens off;` in the `http` block, then reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Test renewal

```bash
sudo certbot renew --dry-run
sudo systemctl status certbot.timer
sudo systemctl list-timers | grep certbot
```

## Verification

```bash
sudo nginx -t
ls /run/php/
sudo systemctl status php<PHP_VERSION>-fpm
sudo supervisorctl status
curl -I https://<DOMAIN>
sudo certbot certificates
```
