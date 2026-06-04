#!/bin/bash

# 未安装MySQL服务端，跳过本地数据库初始化
if [ ! -x /usr/sbin/mysqld ]; then
    echo "local MySQL server not installed, skip local db init."
    exit 0
fi

# MySQL 使用 64 位 jemalloc 配置
# shellcheck source=lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_64

# 判断本地数据库是否初始化过,端口号4000
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ]; then
    echo "use local mysql service"
    # 密码哈希, 用于检测密码是否变化
    pw_marker_file=/var/lib/mysql/.dnf_db_pw.sha256
    # 是否需要初始化
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "prepare to init local mysql data....."
        rm -rf /var/lib/mysql/*
        rm -f "$pw_marker_file"
        # 启动mysql
        mysql_install_db --user=mysql
    else
        echo "local mysql data already inited."
    fi

    chown -R mysql:mysql /var/lib/mysql

    SOCKET=/var/lib/mysql/mysql.sock

    pw_marker=$(printf '%s' "$DNF_DB_ROOT_PASSWORD" | sha256sum | awk '{print $1}')

    if [ -f "$pw_marker_file" ] && [ "$(cat "$pw_marker_file")" = "$pw_marker" ]; then
        echo "root password unchanged, skip reset."
        /etc/init.d/mysql start
        bash /home/template/init/wait-for-mysql.sh
    else
        # 首次启动或密码变化, 先用 --skip-grant-tables 启动重置 root 密码, 再正常启动
        echo "root password changed or first init, reset via skip-grant-tables."
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
        MYSQL_PWD="$DNF_DB_ROOT_PASSWORD" mysqladmin -u root --socket="$SOCKET" shutdown
        for _ in $(seq 1 30); do
            [ ! -S "$SOCKET" ] && break
            sleep 1
        done
        echo "start local mysql...."
        /etc/init.d/mysql start
        bash /home/template/init/wait-for-mysql.sh
        # 仅当 root 使用新密码登录成功时才写哈希, 若登录失败需要删掉哈希下次启动再重置
        if MYSQL_PWD="$DNF_DB_ROOT_PASSWORD" mysql -u root --socket="$SOCKET" -e 'select 1' >/dev/null 2>&1; then
            printf '%s' "$pw_marker" >"$pw_marker_file"
            chmod 600 "$pw_marker_file" 2>/dev/null || true
        else
            echo "ERROR: root password not applied, marker not written, will retry next boot." >&2
            rm -f "$pw_marker_file"
        fi
    fi
fi
