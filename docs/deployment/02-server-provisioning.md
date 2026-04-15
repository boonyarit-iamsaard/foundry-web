# Server Provisioning

Use this document once per fresh Ubuntu VPS. Run the manual steps when you want full control, or start from `scripts/provision.sh` when you want a repeatable bootstrap template.

## Phase A: Base Host Setup

### Connect as root

```bash
ssh root@<SERVER_IP>
```

### Update the system

```bash
apt update && apt upgrade -y
apt install -y curl wget git unzip software-properties-common ufw fail2ban \
  htop iotop nethogs logrotate
```

### Create the deploy user

```bash
adduser <DEPLOY_USER>
usermod -aG sudo <DEPLOY_USER>
id <DEPLOY_USER>
```

### Configure SSH keys for the deploy user

On the local machine:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <DEPLOY_USER>@<SERVER_IP>
```

Manual fallback on the server:

```bash
mkdir -p /home/<DEPLOY_USER>/.ssh
chmod 700 /home/<DEPLOY_USER>/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> /home/<DEPLOY_USER>/.ssh/authorized_keys
chown -R <DEPLOY_USER>:<DEPLOY_USER> /home/<DEPLOY_USER>/.ssh
chmod 600 /home/<DEPLOY_USER>/.ssh/authorized_keys
```

### Harden SSH

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
nano /etc/ssh/sshd_config
```

Set or confirm:

```text
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
X11Forwarding no
AllowUsers <DEPLOY_USER>
MaxAuthTries 3
LoginGraceTime 30
```

Restart SSH:

```bash
systemctl restart ssh
```

Do not close the current root session until both checks pass. Open a new terminal and verify:

```bash
ssh <DEPLOY_USER>@<SERVER_IP>
# Must connect successfully without a password prompt

ssh root@<SERVER_IP>
# Must fail with publickey permission denied
```

### Configure firewall

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status verbose
```

### Configure Fail2Ban

```bash
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
nano /etc/fail2ban/jail.local
```

Update:

```ini
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd
```

```bash
systemctl enable fail2ban
systemctl start fail2ban
systemctl status fail2ban
```

### Configure swap on small hosts

Use this if the VPS has 4 GB RAM or less:

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
swapon --show
free -h
```

### Set timezone and NTP

```bash
timedatectl set-timezone UTC
timedatectl set-ntp true
timedatectl status
```

## Phase B: Runtime and Dependencies

After the base host is hardened, continue as the deploy user:

```bash
ssh <DEPLOY_USER>@<SERVER_IP>
```

### Add the PHP package repository

```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
```

### Install PHP and extensions

```bash
PHP_VERSION="8.4"

sudo apt install -y \
  php${PHP_VERSION}-fpm \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-redis \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-bcmath \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-tokenizer \
  php${PHP_VERSION}-dom \
  php${PHP_VERSION}-fileinfo \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-readline
```

Verify:

```bash
php -v
php-fpm${PHP_VERSION} -v
```

### Install Nginx

```bash
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx
```

### Install Composer

```bash
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
COMPOSER_HASH=$(curl -sS https://composer.github.io/installer.sig)
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '${COMPOSER_HASH}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
composer --version
```

### Install Node.js and pnpm

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
corepack enable
corepack prepare pnpm@latest --activate
node --version
pnpm --version
```

### Install Redis

```bash
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
redis-cli ping
```

Confirm Redis is local-only:

```bash
sudo nano /etc/redis/redis.conf
sudo systemctl restart redis-server
```

Verify `bind 127.0.0.1 ::1` and `protected-mode yes`.

### Install Supervisor

```bash
sudo apt install -y supervisor
sudo systemctl enable supervisor
sudo systemctl start supervisor
sudo systemctl status supervisor
```

### Tune PHP-FPM

Update the default pool or use an app-specific pool later in the web setup guide.

```bash
sudo nano /etc/php/<PHP_VERSION>/fpm/pool.d/www.conf
```

Recommended baseline:

```ini
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 500
```

Update production settings:

```bash
sudo nano /etc/php/<PHP_VERSION>/fpm/php.ini
```

```ini
expose_php = Off
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 60
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.validate_timestamps = 0
```

Restart PHP-FPM:

```bash
sudo systemctl restart php<PHP_VERSION>-fpm
sudo systemctl status php<PHP_VERSION>-fpm
```

## Verification

```bash
ufw status verbose
systemctl status fail2ban
php -v
composer --version
node --version
pnpm --version
redis-cli ping
sudo systemctl status nginx
sudo systemctl status php8.4-fpm
sudo systemctl status supervisor
```
