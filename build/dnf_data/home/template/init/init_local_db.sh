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

    # 修改创建root账号
    service mysql start --skip-grant-tables
    bash /home/template/init/wait_for_mysql.sh
    mysql -u root <<EOF
    delete from mysql.user;
    flush privileges;
    grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
    flush privileges;
EOF
    echo "update root password done."
    # 关闭服务
    service mysql stop
    echo "start local mysql...."
    service mysql start
    bash /home/template/init/wait_for_mysql.sh
fi
