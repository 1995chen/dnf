#!/bin/bash

# 用法: wait-for-mysql.sh [host] [port] [password] [max_retries] [retry_interval]
# 环境变量覆盖: WAIT_FOR_MYSQL_MAX_RETRIES, WAIT_FOR_MYSQL_RETRY_INTERVAL
#
# 说明: 只要服务端能响应，mysqladmin ping 就返回 alive，鉴权失败也算 alive
# 作为 TCP 可达性检查，不验证凭据
# --skip-grant-tables 启动阶段或密码未设置的窗口内，调用方仍能得到 "已就绪"

MYSQL_HOST="${1:-${CUR_MAIN_DB_HOST:-127.0.0.1}}"
MYSQL_PORT="${2:-${CUR_MAIN_DB_PORT:-4000}}"
MYSQL_PASSWORD="${3:-${CUR_MAIN_DB_ROOT_PASSWORD:-$DNF_DB_ROOT_PASSWORD}}"
MAX_RETRIES="${4:-${WAIT_FOR_MYSQL_MAX_RETRIES:-240}}"
RETRY_INTERVAL="${5:-${WAIT_FOR_MYSQL_RETRY_INTERVAL:-2}}"

echo "waiting for mysql at ${MYSQL_HOST}:${MYSQL_PORT} ..."

# 服务端有应答即就绪，哪怕拒绝凭据。alive、或服务端级拒绝如 Access denied、
# not allowed to connect，都证明 mysqld 已起。只有 Can't connect 这类传输层
# 失败才算未就绪。这里不验证凭据。
wfm_ready() {
    local out
    out="$(MYSQL_PWD="$MYSQL_PASSWORD" mysqladmin ping -h "$MYSQL_HOST" -P "$MYSQL_PORT" \
        -u root --connect-timeout=3 2>&1)"
    case "$out" in
    *alive* | *"Access denied"* | *"not allowed to connect"*) return 0 ;;
    *) return 1 ;;
    esac
}

for i in $(seq 1 "$MAX_RETRIES"); do
    if wfm_ready; then
        echo "mysql is ready (${MYSQL_HOST}:${MYSQL_PORT})."
        exit 0
    fi
    echo "mysql not ready, attempt ${i}/${MAX_RETRIES} ..."
    sleep "$RETRY_INTERVAL"
done

echo "ERROR: mysql at ${MYSQL_HOST}:${MYSQL_PORT} did not become ready after ${MAX_RETRIES} attempts (${RETRY_INTERVAL}s interval)." >&2
exit 1
