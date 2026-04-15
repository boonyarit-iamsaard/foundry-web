#!/usr/bin/env bash

# Release rollback template.
# Run as the deploy user after configuring the values below.
# Usage: ./scripts/rollback.sh [release_timestamp]

set -euo pipefail

APP_NAME="<APP_NAME>"
DEPLOY_PATH="/var/www/${APP_NAME}"
PHP_VERSION="8.4"

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

for command_name in php sudo pg_dump gzip; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command_name}"
    exit 1
  }
done

CURRENT="$(readlink "${DEPLOY_PATH}/current")"

if [[ -n "${1:-}" ]]; then
  TARGET="${DEPLOY_PATH}/releases/${1}"
else
  TARGET="${DEPLOY_PATH}/releases/$(ls -1t "${DEPLOY_PATH}/releases/" | sed -n '2p')"
fi

if [[ ! -d "${TARGET}" ]]; then
  echo "Target release not found: ${TARGET}"
  ls -1t "${DEPLOY_PATH}/releases/"
  exit 1
fi

step "Current release"
echo "${CURRENT}"

step "Taking database backup"
BACKUP_DIR="${DEPLOY_PATH}/backups"
mkdir -p "${BACKUP_DIR}"
set -a
. "${DEPLOY_PATH}/shared/.env"
set +a
PGPASSWORD="${DB_PASSWORD}" pg_dump -U "${DB_USERNAME}" -h 127.0.0.1 "${DB_DATABASE}" | gzip > "${BACKUP_DIR}/pre_rollback_$(date +%Y%m%d%H%M%S).sql.gz"

step "Switching to ${TARGET}"
ln -sfn "${TARGET}" "${DEPLOY_PATH}/current"

step "Reloading services"
sudo systemctl reload "php${PHP_VERSION}-fpm"
php "${DEPLOY_PATH}/current/artisan" queue:restart

step "Rollback completed"
echo "Active release: $(readlink "${DEPLOY_PATH}/current")"
php "${DEPLOY_PATH}/current/artisan" --version
