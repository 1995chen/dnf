#!/bin/bash
set -eo pipefail

# 清除残留的运行时文件
rm -f /var/lib/mysql/mysql.sock
rm -f /var/lib/mysql/*.pid
rm -f /var/lib/mysql/*.err

# 确保目录存在且权限正确
mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
chmod 750 /var/lib/mysql /var/run/mysqld

SOCKET=/var/lib/mysql/mysql.sock

# 首次启动时初始化数据库
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing mysql data directory..."
    rm -rf /var/lib/mysql/*
    /usr/local/mysql/bin/mysqld \
        --defaults-file=/etc/my.cnf \
        --initialize-insecure \
        --user=mysql \
        --basedir=/usr/local/mysql \
        --datadir=/var/lib/mysql \
        --explicit_defaults_for_timestamp
else
    echo "mysql data already initialized."
fi

# 每次启动都重置root账号，支持通过环境变量更新密码
echo "configuring root user..."
/usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf --skip-grant-tables &

for _ in $(seq 1 30); do
    if /usr/local/mysql/bin/mysqladmin ping \
        --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
        break
    fi
    sleep 2
done

if ! /usr/local/mysql/bin/mysqladmin ping \
    --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
    echo "ERROR: mysql failed to start within 60 seconds."
    exit 1
fi

/usr/local/mysql/bin/mysql -u root --socket="$SOCKET" <<EOF
DELETE FROM mysql.user;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# 等待socket文件消失，确认关闭完成
/usr/local/mysql/bin/mysqladmin --socket="$SOCKET" shutdown 2>/dev/null
for _ in $(seq 1 15); do
    [ ! -S "$SOCKET" ] && break
    sleep 1
done

echo "starting mysql..."
chown -R mysql:mysql /var/lib/mysql
exec /usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf
