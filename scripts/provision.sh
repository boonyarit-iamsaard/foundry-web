#!/usr/bin/env bash

# One-time Ubuntu VPS provisioning template.
# Run as root on a fresh Ubuntu 22.04 or 24.04 host.
# Usage: ./scripts/provision.sh [deploy_user] [php_version]

set -euo pipefail

DEPLOY_USER="${1:-deployer}"
PHP_VERSION="${2:-8.4}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root."
    exit 1
  fi
}

step() {
  echo
  echo "==> $1"
}

require_root

step "Updating system packages"
apt update && apt upgrade -y
apt install -y curl wget git unzip software-properties-common ufw fail2ban \
  htop iotop nethogs logrotate

step "Creating deploy user"
if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
  usermod -aG sudo "${DEPLOY_USER}"
fi

step "Installing PHP ${PHP_VERSION}"
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y \
  "php${PHP_VERSION}-fpm" \
  "php${PHP_VERSION}-cli" \
  "php${PHP_VERSION}-common" \
  "php${PHP_VERSION}-pgsql" \
  "php${PHP_VERSION}-redis" \
  "php${PHP_VERSION}-zip" \
  "php${PHP_VERSION}-gd" \
  "php${PHP_VERSION}-mbstring" \
  "php${PHP_VERSION}-curl" \
  "php${PHP_VERSION}-xml" \
  "php${PHP_VERSION}-bcmath" \
  "php${PHP_VERSION}-intl" \
  "php${PHP_VERSION}-tokenizer" \
  "php${PHP_VERSION}-dom" \
  "php${PHP_VERSION}-fileinfo" \
  "php${PHP_VERSION}-opcache" \
  "php${PHP_VERSION}-readline"

step "Installing Nginx"
apt install -y nginx
systemctl enable nginx
systemctl start nginx

step "Installing Composer"
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
COMPOSER_HASH="$(curl -sS https://composer.github.io/installer.sig)"
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '${COMPOSER_HASH}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); exit(1); } echo PHP_EOL;"
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

step "Installing Node.js and pnpm"
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs
corepack enable
corepack prepare pnpm@latest --activate

step "Installing Redis and Supervisor"
apt install -y redis-server supervisor
systemctl enable redis-server supervisor
systemctl start redis-server supervisor

step "Configuring firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

step "Configuring Fail2Ban"
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/bantime  = 10m/bantime  = 3600/' /etc/fail2ban/jail.local
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

step "Configuring swap if needed"
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

step "Applying baseline PHP-FPM hardening"
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
sed -i 's/expose_php = On/expose_php = Off/' "${PHP_INI}"
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' "${PHP_INI}"
sed -i 's/post_max_size = 8M/post_max_size = 64M/' "${PHP_INI}"
sed -i 's/memory_limit = 128M/memory_limit = 256M/' "${PHP_INI}"
sed -i 's/;opcache.enable=1/opcache.enable=1/' "${PHP_INI}"
sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=128/' "${PHP_INI}"
sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=0/' "${PHP_INI}"
systemctl restart "php${PHP_VERSION}-fpm"

step "Setting timezone"
timedatectl set-timezone UTC
timedatectl set-ntp true

step "Provisioning completed"
echo "Next steps:"
echo "1. Add the SSH public key for ${DEPLOY_USER}."
echo "2. Harden /etc/ssh/sshd_config and verify non-root access."
echo "3. Continue with docs/deployment/03-database-and-bootstrap.md."
