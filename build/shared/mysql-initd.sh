#!/bin/bash

export PATH=/usr/local/mysql/bin:$PATH
: "${SOCKET:=/var/lib/mysql/mysql.sock}"
: "${MYSQLADMIN:=/usr/local/mysql/bin/mysqladmin}"
: "${MYSQL_START_MAX_TRIES:=120}"
: "${MYSQL_START_SLEEP:=2}"

mysql_initd_ready() {
    local out
    out="$("$MYSQLADMIN" ping --socket="$SOCKET" 2>&1)"
    case "$out" in
    *alive* | *"Access denied"* | *"not allowed to connect"*) return 0 ;;
    *) return 1 ;;
    esac
}
mysql_initd_wait() {
    local _
    for _ in $(seq 1 "$MYSQL_START_MAX_TRIES"); do
        if mysql_initd_ready; then
            return 0
        fi
        sleep "$MYSQL_START_SLEEP"
    done
    echo "mysql failed to start within $((MYSQL_START_MAX_TRIES * MYSQL_START_SLEEP)) seconds" >&2
    return 1
}

mysql_initd_main() {
    case "$1" in
    start)
        shift
        mkdir -p /var/run/mysqld /var/log/mysql
        chown mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql
        chmod 750 /var/run/mysqld
        /usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf "$@" &
        mysql_initd_wait
        exit $?
        ;;
    stop)
        # 优先用配置的 root 密码做优雅关闭
        if [ -n "$DNF_DB_ROOT_PASSWORD" ]; then
            "$MYSQLADMIN" -u root -p"$DNF_DB_ROOT_PASSWORD" --socket="$SOCKET" shutdown 2>/dev/null
        else
            "$MYSQLADMIN" -u root --socket="$SOCKET" shutdown 2>/dev/null
        fi
        for _ in $(seq 1 30); do
            [ ! -S "$SOCKET" ] && exit 0
            sleep 1
        done
        echo "mysql did not shut down within 30 seconds" >&2
        exit 1
        ;;
    restart)
        "$0" stop
        exec "$0" start "$@"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}" >&2
        exit 1
        ;;
    esac
}

# 仅在被执行时动作，允许测试 source。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    mysql_initd_main "$@"
fi
