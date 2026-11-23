#!/usr/bin/env bash

# Laravel DevOps Home Lab - Comprehensive Healthcheck
# Checks: Disk Blocks, Disk Inodes, Filesystem R/W, RAM,
# Docker daemon, Compose services, MariaDB health/query/capacity, and HTTP endpoint.

set -uo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DISK_THRESHOLD=80
INODE_THRESHOLD=80
MEM_THRESHOLD=85
MIN_DB_CONNECTIONS=20
DB_CONN_USAGE_THRESHOLD=80
HTTP_URL="http://127.0.0.1:8080/"

FAILED_CHECKS=0
TOTAL_CHECKS=0

# --------------------------------------------------
# Output helpers
# --------------------------------------------------

print_header() {
    echo
    echo "========================================"
    echo " Laravel DevOps Home Lab - Healthcheck"
    echo "========================================"
    echo
}

check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf '[PASS] %s\n' "$1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    printf '[FAIL] %s\n' "$1" >&2
}

# --------------------------------------------------
# Project directory
# --------------------------------------------------

print_header

cd "$PROJECT_DIR" || {
    check_fail "Cannot access project directory: $PROJECT_DIR"
    exit 1
}

echo "[INFO] Project directory: $PROJECT_DIR"

# --------------------------------------------------
# 1. Disk Space, Inodes & Read/Write Health
# --------------------------------------------------

DISK_USAGE="$(df -P "$PROJECT_DIR" | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [[ "$DISK_USAGE" =~ ^[0-9]+$ ]]; then
    if (( DISK_USAGE < DISK_THRESHOLD )); then
        check_pass "Disk space usage: ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    else
        check_fail "Disk space usage is high: ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    fi
else
    check_fail "Unable to determine disk space usage"
fi

INODE_USAGE="$(df -Pi "$PROJECT_DIR" | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [[ "$INODE_USAGE" =~ ^[0-9]+$ ]]; then
    if (( INODE_USAGE < INODE_THRESHOLD )); then
        check_pass "Disk Inode usage: ${INODE_USAGE}% (threshold: ${INODE_THRESHOLD}%)"
    else
        check_fail "Disk Inode usage is high: ${INODE_USAGE}% (threshold: ${INODE_THRESHOLD}%)"
    fi
else
    check_fail "Unable to determine disk Inode usage"
fi

TEST_RW_FILE="/tmp/.hc_rw_test_$$"
if touch "$TEST_RW_FILE" 2>/dev/null; then
    rm -f "$TEST_RW_FILE"
    check_pass "Filesystem Read/Write check: active (RW)"
else
    check_fail "Filesystem is Read-Only or I/O error occurred"
fi

# --------------------------------------------------
# 2. System Memory (RAM)
# --------------------------------------------------

MEM_USAGE="$(free | awk '/Mem:/ {printf("%.0f", ($2-$7)/$2 * 100)}')"
if [[ "$MEM_USAGE" =~ ^[0-9]+$ ]]; then
    if (( MEM_USAGE < MEM_THRESHOLD )); then
        check_pass "Memory (RAM) usage: ${MEM_USAGE}% (threshold: ${MEM_THRESHOLD}%)"
    else
        check_fail "Memory (RAM) usage is high: ${MEM_USAGE}% (threshold: ${MEM_THRESHOLD}%)"
    fi
else
    check_fail "Unable to determine memory usage"
fi

# --------------------------------------------------
# 3. Required commands & Docker daemon
# --------------------------------------------------

for cmd in docker curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        check_fail "Required command '$cmd' is not installed or not in PATH"
        exit 1
    fi
done

if timeout -k 2s 10s docker version --format '{{.Server.Version}}' >/dev/null 2>&1 </dev/null; then

    check_pass "Docker daemon is accessible"
else
    check_fail "Docker daemon is not accessible or timed out"
fi

# --------------------------------------------------
# 4. Docker Compose services
# --------------------------------------------------

check_compose_service() {
    local service="$1"
    local container_id
    local container_status

    container_id="$(docker compose ps -a -q "$service" 2>/dev/null </dev/null)"

    if [[ -z "$container_id" ]]; then
        check_fail "Compose service '$service': container not found"
        return 1
    fi

    container_status="$(docker inspect --format '{{.State.Status}}' "$container_id" 2>/dev/null </dev/null)"

    if [[ "$container_status" == "running" ]]; then
        check_pass "Compose service '$service' is running"
        return 0
    else
        check_fail "Compose service '$service' is not running (status: ${container_status:-unknown})"
        return 1
    fi
}

check_compose_service "mysql"
MYSQL_RUNNING=$?

check_compose_service "php"
PHP_RUNNING=$?

check_compose_service "nginx"
NGINX_RUNNING=$?

# --------------------------------------------------
# 5 & 6. MariaDB container health, SQL responsiveness & capacity
# --------------------------------------------------

if (( MYSQL_RUNNING == 0 )); then
    MYSQL_CONTAINER_ID="$(docker compose ps -q mysql 2>/dev/null </dev/null)"

    MYSQL_HEALTH="$(docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
        "$MYSQL_CONTAINER_ID" 2>/dev/null </dev/null)"

    if [[ "$MYSQL_HEALTH" == "healthy" ]]; then
        check_pass "MariaDB container healthcheck: healthy"
    else
        check_fail "MariaDB container healthcheck: ${MYSQL_HEALTH:-unknown}"
    fi

    # 6a. Verify App-User SQL query execution (non-interactive, stdin closed)
    if APP_DB_CHECK="$(timeout --foreground -k 2s 5s docker exec "$MYSQL_CONTAINER_ID" sh -c \
        'mariadb -h 127.0.0.1 -u "$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" --connect-timeout=2 -N -s -e "SELECT 1;"' </dev/null 2>&1)"; then
        check_pass "MariaDB application user SQL query ('SELECT 1') succeeded"
    else
        check_fail "MariaDB application query failed: ${APP_DB_CHECK:-timeout}"
    fi

    # 6b. Verify Connection Pool Capacity (max_connections & active threads)
    if DB_CONN_STATS="$(timeout --foreground -k 2s 5s docker exec "$MYSQL_CONTAINER_ID" sh -c \
        'mariadb -h 127.0.0.1 -u root -p"$MARIADB_ROOT_PASSWORD" --connect-timeout=2 -N -s -e "SELECT @@GLOBAL.max_connections, VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME=\"Threads_connected\";"' </dev/null 2>&1)"; then
        MAX_CONN="$(echo "$DB_CONN_STATS" | awk '{print $1}')"
        ACTIVE_CONN="$(echo "$DB_CONN_STATS" | awk '{print $2}')"
        CONN_USAGE=$(( ACTIVE_CONN * 100 / (MAX_CONN > 0 ? MAX_CONN : 1) ))

        if (( MAX_CONN < MIN_DB_CONNECTIONS )); then
            check_fail "MariaDB max_connections is dangerously low: ${MAX_CONN} (minimum required: ${MIN_DB_CONNECTIONS})"
        elif (( CONN_USAGE >= DB_CONN_USAGE_THRESHOLD )); then
            check_fail "MariaDB connection pool usage is high: ${ACTIVE_CONN}/${MAX_CONN} (${CONN_USAGE}%)"
        else
            check_pass "MariaDB connection pool healthy: ${ACTIVE_CONN}/${MAX_CONN} active (${CONN_USAGE}%)"
        fi
    else
        check_fail "Unable to query MariaDB connection capacity: ${DB_CONN_STATS:-timeout}"
    fi
else
    check_fail "MariaDB checks skipped because container is not running"
fi

# --------------------------------------------------
# 7. HTTP endpoint
# --------------------------------------------------

HTTP_STATUS="$(curl \
    --silent \
    --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --connect-timeout 5 \
    --max-time 10 \
    "$HTTP_URL" 2>/dev/null </dev/null)"
CURL_EXIT=$?

if (( CURL_EXIT == 0 )); then
    case "$HTTP_STATUS" in
        200|302)
            check_pass "HTTP endpoint responded with status $HTTP_STATUS"
            ;;
        *)
            check_fail "HTTP endpoint returned unexpected status: $HTTP_STATUS"
            ;;
    esac
else
    check_fail "HTTP endpoint is unreachable (curl exit code: $CURL_EXIT)"
fi

# --------------------------------------------------
# 8. Final summary
# --------------------------------------------------

echo
echo "========================================"
echo " Healthcheck Summary"
echo "========================================"
echo "Total checks : $TOTAL_CHECKS"
echo "Passed       : $((TOTAL_CHECKS - FAILED_CHECKS))"
echo "Failed       : $FAILED_CHECKS"
echo "========================================"

if (( FAILED_CHECKS == 0 )); then
    echo "[RESULT] ALL CHECKS PASSED"
    exit 0
else
    echo "[RESULT] HEALTHCHECK FAILED"
    exit 1
fi
