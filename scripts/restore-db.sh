#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${PROJECT_DIR}/.env" ]]; then
    export $(grep -E '^(MARIADB_DATABASE|MARIADB_ROOT_PASSWORD)=' "${PROJECT_DIR}/.env" | xargs)
else
    echo "ERROR: .env file not found" >&2
    exit 1
fi

if [[ -z "${1:-}" ]] || [[ ! -f "$1" ]]; then
    echo "Usage: $0 <path_to_backup_file.sql.gz>"
    exit 1
fi

RESTORE_FILE="$1"
echo "=== [Restoring Database: ${MARIADB_DATABASE} from ${RESTORE_FILE}] ==="

# اکسترکت در لحظه و تزریق مستقیم به دیتابیس
zcat "${RESTORE_FILE}" | docker compose exec -T mysql mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}"

echo "=== [Restore Completed Successfully!] ==="
