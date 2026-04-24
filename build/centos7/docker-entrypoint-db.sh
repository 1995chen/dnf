#!/bin/bash
set -eo pipefail

# 清理残留的运行时文件
rm -f /var/lib/mysql/mysql.sock
rm -f /var/lib/mysql/mysql.sock.lock
rm -f /var/lib/mysql/*.pid
rm -f /var/lib/mysql/*.err

SOCKET=/var/lib/mysql/mysql.sock

# 首次启动时初始化数据库
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "initializing local mysql data..."
    rm -rf /var/lib/mysql/*
    mysql_install_db --user=mysql
else
    echo "local mysql data already initialized."
fi

echo "configuring root user..."
/usr/bin/mysqld_safe --user=mysql --datadir=/var/lib/mysql \
    --socket="$SOCKET" --skip-grant-tables --skip-networking &

for _ in $(seq 1 30); do
    if /usr/bin/mysqladmin ping --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
        break
    fi
    sleep 2
done

if ! /usr/bin/mysqladmin ping --socket="$SOCKET" 2>/dev/null | grep -q "alive"; then
    echo "ERROR: mysql failed to start within 60 seconds."
    exit 1
fi

mysql -u root --socket="$SOCKET" <<EOF
DELETE FROM mysql.user;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

/usr/bin/mysqladmin -u root -p"$DNF_DB_ROOT_PASSWORD" --socket="$SOCKET" shutdown
for _ in $(seq 1 30); do
    [ ! -S "$SOCKET" ] && break
    sleep 1
done

chown -R mysql:mysql /var/lib/mysql
exec /usr/bin/mysqld_safe --datadir=/var/lib/mysql --pid-file="/var/lib/mysql/$(hostname).pid"
