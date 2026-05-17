#!/bin/bash

# 未安装MySQL服务端，跳过本地数据库初始化
if [ ! -x /usr/sbin/mysqld ]; then
    echo "local MySQL server not installed, skip local db init."
    exit 0
fi

# 判断本地数据库是否初始化过,端口号4000
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ]; then
    echo "use local mysql service"
    # 是否需要初始化
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "prepare to init local mysql data....."
        # 清理数据
        rm -rf /var/lib/mysql/*
        # 启动mysql
        mysql_install_db --user=mysql
    else
        echo "local mysql data already inited."
    fi

    chown -R mysql:mysql /var/lib/mysql

    SOCKET=/var/lib/mysql/mysql.sock

    # 先用 --skip-grant-tables 启动 root 账号，再以正常模式重启
    # 直接调用 init.d 脚本，跳过 service 命令对 systemd/D-Bus 的探测
    /etc/init.d/mysql start --skip-grant-tables
    bash /home/template/init/wait-for-mysql.sh
    mysql -u root --socket="$SOCKET" <<EOF
    delete from mysql.user;
    flush privileges;
    grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
    grant all privileges on *.* to 'root'@'localhost' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
    flush privileges;
EOF
    echo "update root password done."
    # FLUSH PRIVILEGES 之后mysql重新启用鉴权
    mysqladmin -u root -p"$DNF_DB_ROOT_PASSWORD" --socket="$SOCKET" shutdown
    for _ in $(seq 1 30); do
        [ ! -S "$SOCKET" ] && break
        sleep 1
    done
    echo "start local mysql...."
    /etc/init.d/mysql start
    bash /home/template/init/wait-for-mysql.sh
fi
