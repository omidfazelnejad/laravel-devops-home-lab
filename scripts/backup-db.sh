#!/usr/bin/env bash

# توقف اسکریپت در صورت بروز هرگونه خطا یا متغیر تعریف‌نشده
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"

if [[ -f "${PROJECT_DIR}/.env" ]]; then
    export $(grep -E '^(MARIADB_DATABASE|MARIADB_ROOT_PASSWORD)=' "${PROJECT_DIR}/.env" | xargs)
else
    echo "ERROR: .env file not found in ${PROJECT_DIR}" >&2
    exit 1
fi

BACKUP_FILE="${BACKUP_DIR}/${MARIADB_DATABASE}_${TIMESTAMP}.sql.gz"

echo "=== [Database Backup Started: ${TIMESTAMP}] ==="

# گرفتن دامپ اتمیک و فشرده‌سازی
docker compose exec -T mysql mariadb-dump \
    -u root \
    -p"${MARIADB_ROOT_PASSWORD}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    "${MARIADB_DATABASE}" | gzip > "${BACKUP_FILE}"

echo "--- Validating Backup Integrity ---"

# ۱. تست سلامت فیزیکی فایل فشرده
if ! gzip -t "${BACKUP_FILE}" 2>/dev/null; then
    echo "ERROR: Backup archive is corrupted (gzip test failed)!" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# ۲. تست یکپارچگی داده‌ها (بررسی فوتر دیتابیس)
if ! zcat "${BACKUP_FILE}" | tail -n 5 | grep -q "Dump completed"; then
    echo "ERROR: Backup is incomplete (missing MariaDB dump footer)!" >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi

FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "SUCCESS: Backup completed and validated!"
echo "File: ${BACKUP_FILE} (Size: ${FILE_SIZE})"
