#!/bin/bash

# 用法: wait_for_mysql.sh [host] [port] [password] [max_retries] [retry_interval]

MYSQL_HOST="${1:-${CUR_MAIN_DB_HOST:-127.0.0.1}}"
MYSQL_PORT="${2:-${CUR_MAIN_DB_PORT:-4000}}"
MYSQL_PASSWORD="${3:-${CUR_MAIN_DB_ROOT_PASSWORD:-$DNF_DB_ROOT_PASSWORD}}"
MAX_RETRIES="${4:-30}"
RETRY_INTERVAL="${5:-2}"

echo "waiting for mysql at ${MYSQL_HOST}:${MYSQL_PORT} ..."

for i in $(seq 1 "$MAX_RETRIES"); do
    if mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
        -u root -p"$MYSQL_PASSWORD" --connect-timeout=3 2>/dev/null | grep -q "alive"; then
        echo "mysql is ready (${MYSQL_HOST}:${MYSQL_PORT})."
        exit 0
    fi
    echo "mysql not ready, attempt ${i}/${MAX_RETRIES} ..."
    sleep "$RETRY_INTERVAL"
done

echo "ERROR: mysql at ${MYSQL_HOST}:${MYSQL_PORT} did not become ready within $((MAX_RETRIES * RETRY_INTERVAL))s."
exit 1
