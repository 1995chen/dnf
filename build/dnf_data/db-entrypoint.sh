#!/bin/bash

rm -f /var/lib/mysql/mysql.sock /var/lib/mysql/mysql.sock.lock \
    /var/lib/mysql/*.pid /var/lib/mysql/*.err \
    /var/run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock.lock \
    /var/run/mysqld/*.pid

# shellcheck source=/dev/null
source /home/template/init/lib/mysql.sh
# shellcheck source=/dev/null
source /home/template/init/lib/common.sh
# shellcheck source=/dev/null
source /home/template/init/lib/tune.sh

# my.cnf 使用 !includedir /data/my.cnf.d，MySQL 5.0 需要确保此目录存在
mkdir -p /data/my.cnf.d || true

tune_resolve_and_export "yes"
tune_apply_malloc_conf_64

if ! mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql; then
    echo "ERROR: mkdir failed for mysql directories." >&2
    exit 1
fi

# 首次启动时初始化数据库
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing mysql data directory..."
    rm -rf /var/lib/mysql/*
    if ! mysql_first_boot_init; then
        echo "ERROR: mysql first boot init failed." >&2
        exit 1
    fi
else
    echo "mysql data already initialized."
fi

if ! chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql; then
    echo "ERROR: chown failed for mysql directories." >&2
    exit 1
fi
if ! chmod 750 /var/lib/mysql /var/run/mysqld; then
    echo "ERROR: chmod failed for mysql directories." >&2
    exit 1
fi

# 每次启动用 --init-file 调整 root 密码
if ! mysql_write_init_sql /run/mysql/init.sql "$DNF_DB_ROOT_PASSWORD"; then
    echo "ERROR: failed to write init.sql" >&2
    exit 1
fi

echo "starting mysqld (foreground, PID1)..."
mysqld_bin=/usr/sbin/mysqld
jemalloc_lib="$(mysql_jemalloc_lib)"
if [ "$(mysql_init_method "$("$mysqld_bin" --no-defaults --version 2>/dev/null)")" = install-db ]; then
    exec env LD_PRELOAD="$jemalloc_lib" "$mysqld_bin" \
        --datadir=/var/lib/mysql --socket=/var/lib/mysql/mysql.sock \
        --pid-file="/var/lib/mysql/$(hostname).pid" --init-file=/run/mysql/init.sql --user=mysql
else
    exec env LD_PRELOAD="$jemalloc_lib" "$mysqld_bin" \
        --defaults-file=/etc/my.cnf --init-file=/run/mysql/init.sql --user=mysql
fi
