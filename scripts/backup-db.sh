#!/usr/bin/env bash

# PostgreSQL backup template.
# Run as the deploy user after configuring the values below.
# Usage: ./scripts/backup-db.sh

set -euo pipefail

APP_NAME="<APP_NAME>"
DEPLOY_PATH="/var/www/${APP_NAME}"
RETENTION_DAYS=30

require_value() {
  local value="$1"
  local name="$2"

  if [[ -z "${value}" || "${value}" == \<* ]]; then
    echo "Configure ${name} before running this script."
    exit 1
  fi
}

require_value "${APP_NAME}" "APP_NAME"

for command_name in pg_dump gzip find; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command_name}"
    exit 1
  }
done

BACKUP_DIR="${DEPLOY_PATH}/backups"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

set -a
. "${DEPLOY_PATH}/shared/.env"
set +a

mkdir -p "${BACKUP_DIR}"

PGPASSWORD="${DB_PASSWORD}" pg_dump -U "${DB_USERNAME}" -h 127.0.0.1 "${DB_DATABASE}" | gzip > "${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz"
find "${BACKUP_DIR}" -name "db_*.sql.gz" -mtime +"${RETENTION_DAYS}" -delete

echo "Backup completed: ${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz"
