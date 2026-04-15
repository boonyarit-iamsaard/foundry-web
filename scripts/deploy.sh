#!/usr/bin/env bash

# Zero-downtime deployment template.
# Run as the deploy user after configuring the values below.
# Usage: ./scripts/deploy.sh

set -euo pipefail

APP_NAME="<APP_NAME>"
REPO_URL="<REPO_URL>"
DEPLOY_PATH="/var/www/${APP_NAME}"
PHP_VERSION="8.4"
KEEP_RELEASES=5

require_value() {
  local value="$1"
  local name="$2"

  if [[ -z "${value}" || "${value}" == \<* ]]; then
    echo "Configure ${name} before running this script."
    exit 1
  fi
}

step() {
  echo
  echo "==> $1"
}

require_value "${APP_NAME}" "APP_NAME"
require_value "${REPO_URL}" "REPO_URL"

for command_name in git composer php pnpm sudo; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command_name}"
    exit 1
  }
done

RELEASE="$(date +%Y%m%d%H%M%S)"
RELEASE_PATH="${DEPLOY_PATH}/releases/${RELEASE}"
SHARED_PATH="${DEPLOY_PATH}/shared"
CURRENT_PATH="${DEPLOY_PATH}/current"

step "Cloning release ${RELEASE}"
git clone --depth=1 "${REPO_URL}" "${RELEASE_PATH}"

step "Linking shared resources"
rm -rf "${RELEASE_PATH}/storage"
ln -sf "${SHARED_PATH}/storage" "${RELEASE_PATH}/storage"
mkdir -p "${RELEASE_PATH}/bootstrap/cache"
ln -sf "${SHARED_PATH}/.env" "${RELEASE_PATH}/.env"

cd "${RELEASE_PATH}"

step "Installing Composer dependencies"
composer install \
  --no-dev \
  --optimize-autoloader \
  --no-interaction \
  --prefer-dist \
  --quiet

step "Installing frontend dependencies and building assets"
if [[ -f "${RELEASE_PATH}/package.json" ]]; then
  pnpm install --frozen-lockfile --silent
  pnpm run build --silent
fi

step "Warming Laravel caches"
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
php artisan storage:link 2>/dev/null || true

step "Applying permissions"
find "${RELEASE_PATH}" -type f -exec chmod 644 {} \;
find "${RELEASE_PATH}" -type d -exec chmod 755 {} \;
chmod -R 775 "${SHARED_PATH}/storage"
chmod -R 775 "${RELEASE_PATH}/bootstrap/cache"
chmod 600 "${SHARED_PATH}/.env"

step "Running migrations"
php artisan migrate --force

step "Activating release"
ln -sfn "${RELEASE_PATH}" "${CURRENT_PATH}"

step "Reloading services"
sudo systemctl reload "php${PHP_VERSION}-fpm"
php "${CURRENT_PATH}/artisan" queue:restart

step "Pruning old releases"
cd "${DEPLOY_PATH}/releases"
for release in $(ls -1t | sed -n "$((KEEP_RELEASES + 1)),\$p"); do
  rm -rf -- "${release}"
done

step "Deployment completed"
echo "Active release: $(readlink "${CURRENT_PATH}")"
