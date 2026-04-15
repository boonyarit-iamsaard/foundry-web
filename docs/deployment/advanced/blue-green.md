# Blue/Green Deployment

Blue/green is optional. Use it only when you need to validate an inactive environment before switching live traffic.

## Tradeoffs

| Dimension             | Zero-Downtime        | Blue/Green          |
| --------------------- | -------------------- | ------------------- |
| Complexity            | Low                  | High                |
| Rollback speed        | Instant symlink swap | Fast traffic switch |
| Resource cost         | 1x                   | 2x                  |
| Pre-switch validation | Limited              | Strong              |

## Layout

```text
/var/www/<APP_NAME>/
├── active -> blue/current
├── blue/
│   └── current -> releases/...
├── green/
│   └── current -> releases/...
├── shared/
├── releases/
└── backups/
```

## Initial Setup

```bash
sudo mkdir -p /var/www/<APP_NAME>/{blue,green}/{releases}
sudo chown -R <DEPLOY_USER>:www-data /var/www/<APP_NAME>/{blue,green}
sudo ln -sfn /var/www/<APP_NAME>/blue/current /var/www/<APP_NAME>/active
echo "blue" > /var/www/<APP_NAME>/.active
```

Update Nginx to point to `/var/www/<APP_NAME>/active/public`.

## Deploy to the Inactive Color

```bash
ACTIVE=$(cat /var/www/<APP_NAME>/.active)
INACTIVE=$([ "$ACTIVE" = "blue" ] && echo "green" || echo "blue")
RELEASE="$(date +%Y%m%d%H%M%S)"
RELEASE_PATH="/var/www/<APP_NAME>/${INACTIVE}/releases/${RELEASE}"
```

Build the inactive release exactly like a normal zero-downtime deploy, then:

```bash
ln -sfn "$RELEASE_PATH" /var/www/<APP_NAME>/${INACTIVE}/current
```

## Validate Before Switching

Expose the inactive color on an internal port or a canary server block:

```nginx
server {
    listen 8080;
    root /var/www/<APP_NAME>/<INACTIVE>/current/public;
}
```

```bash
sudo nginx -t
sudo systemctl reload nginx
curl -I http://localhost:8080
```

## Switch Traffic

```bash
sudo ln -sfn /var/www/<APP_NAME>/${INACTIVE}/current /var/www/<APP_NAME>/active
sudo nginx -t
sudo systemctl reload nginx
echo "$INACTIVE" > /var/www/<APP_NAME>/.active
```

## Roll Back

```bash
CURRENT=$(cat /var/www/<APP_NAME>/.active)
PREVIOUS=$([ "$CURRENT" = "blue" ] && echo "green" || echo "blue")
sudo ln -sfn /var/www/<APP_NAME>/${PREVIOUS}/current /var/www/<APP_NAME>/active
sudo nginx -t
sudo systemctl reload nginx
echo "$PREVIOUS" > /var/www/<APP_NAME>/.active
```
