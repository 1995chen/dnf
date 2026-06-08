#!/bin/bash

# 判断是否配置了外部数据库连接，主库或大区库任一 host/port 非空即视为已配置
# env-resolve 用来判断服务端连 127.0.0.1 还是自定义数据库地址
mysql_external_configured() {
    [ -n "$MAIN_MYSQL_HOST" ] || [ -n "$MAIN_MYSQL_PORT" ] ||
        [ -n "$MYSQL_HOST" ] || [ -n "$MYSQL_PORT" ]
}

# 判断本地是否安装了 MySQL
# server 镜像用来判断是否跳过启动 mysqld
mysql_is_local() {
    local mysqld="${MYSQLD_BIN:-/usr/sbin/mysqld}"
    [ -x "$mysqld" ]
}

# 生成 --init-file SQL, 每次启动重置 root 密码
mysql_render_init_sql() {
    local pw="$1"
    pw=${pw//\\/\\\\}
    pw=${pw//\'/\'\'}
    cat <<EOF
delete from mysql.user where user='' or (user='root' and host not in ('%','localhost'));
grant all privileges on *.* to 'root'@'%' identified by '${pw}' WITH GRANT OPTION;
grant all privileges on *.* to 'root'@'localhost' identified by '${pw}' WITH GRANT OPTION;
flush privileges;
EOF
}

# 将 init.sql 写入指定路径并调整权限
mysql_write_init_sql() {
    local path="$1" pw="$2" dir
    dir=$(dirname "$path")
    mkdir -p "$dir" || return 1
    (
        umask 077
        mysql_render_init_sql "$pw" >"$path"
    ) || return 1
    chown mysql:mysql "$dir" "$path" 2>/dev/null
    return 0
}

# jemalloc 路径，可用 MYSQL_JEMALLOC_LIB 覆盖
mysql_jemalloc_lib() {
    printf '%s' "${MYSQL_JEMALLOC_LIB:-/usr/lib/libjemalloc.so.2}"
}

# 根据不同 mysql 版本区分不同初始化方法
# 5.0/5.1 用 mysql_install_db, 5.7+ 用 --initialize-insecure
mysql_init_method() {
    case "$1" in
    *Ver\ 5.0.* | *Ver\ 5.1.*) printf 'install-db' ;;
    *) printf 'initialize-insecure' ;;
    esac
}

# 初始化 mysql 数据
mysql_first_boot_init() {
    local mysqld="${MYSQLD_BIN:-/usr/sbin/mysqld}"
    if [ "$(mysql_init_method "$("$mysqld" --no-defaults --version 2>/dev/null)")" = install-db ]; then
        mysql_install_db --user=mysql
    else
        "$mysqld" --defaults-file=/etc/my.cnf --initialize-insecure --user=mysql --datadir=/var/lib/mysql
    fi
}
