#!/bin/bash

export PATH=/usr/local/mysql/bin:$PATH
SOCKET=/var/lib/mysql/mysql.sock
MYSQLADMIN=/usr/local/mysql/bin/mysqladmin

case "$1" in
start)
    shift
    mkdir -p /var/run/mysqld /var/log/mysql
    chown mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql
    chmod 750 /var/run/mysqld
    /usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf "$@" &
    # 最长等待 240 秒确认 mysql 可用
    for _ in $(seq 1 120); do
        if "$MYSQLADMIN" ping --socket="$SOCKET" 2>/dev/null | grep -q alive; then
            exit 0
        fi
        sleep 2
    done
    echo "mysql failed to start within 240 seconds" >&2
    exit 1
    ;;
stop)
    # 优先使用环境变量中的 root 密码做 graceful shutdown
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
