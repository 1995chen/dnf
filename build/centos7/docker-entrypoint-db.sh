#!/bin/bash

# 清理残留的运行时文件
rm -f /var/lib/mysql/mysql.sock
rm -f /var/lib/mysql/mysql.sock.lock
rm -f /var/lib/mysql/*.pid
rm -f /var/lib/mysql/*.err

# shellcheck source=/dev/null
source /home/template/init/lib/common.sh
# shellcheck source=/dev/null
source /home/template/init/lib/tune.sh
tune_resolve_and_export "yes"

# MySQL 使用 64 位 jemalloc 配置
tune_apply_malloc_conf_64

SOCKET=/var/lib/mysql/mysql.sock

# 首次启动时初始化数据库
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing local mysql data..."
    rm -rf /var/lib/mysql/*
    if ! mysql_install_db --user=mysql; then
        echo "ERROR: mysql_install_db failed." >&2
        exit 1
    fi
else
    echo "local mysql data already initialized."
fi

echo "configuring root user..."
/usr/bin/mysqld_safe --user=mysql --datadir=/var/lib/mysql \
    --socket="$SOCKET" --skip-grant-tables --skip-networking &

for _ in $(seq 1 120); do
    if /usr/bin/mysqladmin ping --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
        break
    fi
    sleep 2
done

if ! /usr/bin/mysqladmin ping --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
    echo "ERROR: mysql failed to start within 240 seconds." >&2
    exit 1
fi

if ! mysql -u root --socket="$SOCKET" <<EOF; then
DELETE FROM mysql.user;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    echo "ERROR: failed to reset root user." >&2
    exit 1
fi

MYSQL_PWD="$DNF_DB_ROOT_PASSWORD" /usr/bin/mysqladmin -u root --socket="$SOCKET" shutdown || true
for _ in $(seq 1 30); do
    [ ! -S "$SOCKET" ] && break
    sleep 1
done

if ! chown -R mysql:mysql /var/lib/mysql; then
    echo "ERROR: chown failed before final mysqld start." >&2
    exit 1
fi
exec /usr/bin/mysqld_safe --datadir=/var/lib/mysql --pid-file="/var/lib/mysql/$(hostname).pid"
