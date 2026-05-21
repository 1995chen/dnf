#!/bin/bash

# 清理残留的运行时文件
rm -f /var/lib/mysql/mysql.sock
rm -f /var/lib/mysql/mysql.sock.lock
rm -f /var/lib/mysql/*.pid
rm -f /var/lib/mysql/*.err
rm -f /var/run/mysqld/mysqld.sock
rm -f /var/run/mysqld/mysqld.sock.lock
rm -f /var/run/mysqld/*.pid

# shellcheck source=/dev/null
source /home/template/init/lib/common.sh
# shellcheck source=/dev/null
source /home/template/init/lib/tune.sh
tune_resolve_and_export "yes"

# MySQL 使用 64 位 jemalloc 配置
tune_apply_malloc_conf_64

# 确保目录存在且权限正确
if ! mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql; then
    echo "ERROR: mkdir failed for mysql directories." >&2
    exit 1
fi
if ! chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql; then
    echo "ERROR: chown failed for mysql directories." >&2
    exit 1
fi
if ! chmod 750 /var/lib/mysql /var/run/mysqld; then
    echo "ERROR: chmod failed for mysql directories." >&2
    exit 1
fi

SOCKET=/var/lib/mysql/mysql.sock

# 首次启动时初始化数据库
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing mysql data directory..."
    rm -rf /var/lib/mysql/*
    if ! /usr/local/mysql/bin/mysqld \
        --defaults-file=/etc/my.cnf \
        --initialize-insecure \
        --user=mysql \
        --basedir=/usr/local/mysql \
        --datadir=/var/lib/mysql \
        --explicit_defaults_for_timestamp; then
        echo "ERROR: mysqld --initialize-insecure failed." >&2
        exit 1
    fi
else
    echo "mysql data already initialized."
fi

# 每次启动都重置 root 账号，支持通过环境变量更新密码
echo "configuring root user..."
/usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf --skip-grant-tables --skip-networking &

for _ in $(seq 1 120); do
    if /usr/local/mysql/bin/mysqladmin ping \
        --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
        break
    fi
    sleep 2
done

if ! /usr/local/mysql/bin/mysqladmin ping \
    --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
    echo "ERROR: mysql failed to start within 240 seconds." >&2
    exit 1
fi

if ! /usr/local/mysql/bin/mysql -u root --socket="$SOCKET" <<EOF; then
DELETE FROM mysql.user;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    echo "ERROR: failed to reset root user." >&2
    exit 1
fi

/usr/local/mysql/bin/mysqladmin -u root -p"$DNF_DB_ROOT_PASSWORD" --socket="$SOCKET" shutdown || true
for _ in $(seq 1 15); do
    [ ! -S "$SOCKET" ] && break
    sleep 1
done

echo "starting mysql..."
if ! chown -R mysql:mysql /var/lib/mysql; then
    echo "ERROR: chown failed before final mysqld start." >&2
    exit 1
fi
exec /usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf
