#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=/dev/null
source "${SCRIPT_PATH}/mysql.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-40s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}

# mysql_is_local: 本地有 mysqld 则启动, 忽略环境变量(即使用户希望连接外部数据库，也启动本地mysql)
touch "$WORK/mysqld"
chmod +x "$WORK/mysqld"
MYSQLD_BIN="$WORK/mysqld" mysql_is_local
chk "mysql_is_local: true" 0 "$?"

MYSQLD_BIN="$WORK/mysqld" MAIN_MYSQL_HOST=db.example mysql_is_local
chk "mysql_is_local: true" 0 "$?"

# mysql_is_local: 本地无 mysqld 则不启动
MYSQLD_BIN="$WORK/none" mysql_is_local
chk "is_local 无 mysqld" 1 "$?"

(
    unset MAIN_MYSQL_HOST MAIN_MYSQL_PORT MYSQL_HOST MYSQL_PORT
    mysql_external_configured
)
chk "external: 环境变量全为空，使用内部数据库" 1 "$?"
(
    unset MAIN_MYSQL_PORT MYSQL_HOST MYSQL_PORT
    MAIN_MYSQL_HOST=db mysql_external_configured
)
chk "external: 设置 host" 0 "$?"
(
    unset MAIN_MYSQL_HOST MAIN_MYSQL_PORT MYSQL_HOST
    MYSQL_PORT=3306 mysql_external_configured
)
chk "external: 设置 port" 0 "$?"

# mysql_render_init_sql: 含 GRANT + FLUSH, 不含 DELETE 语句
out=$(mysql_render_init_sql "88888888")
chk "init_sql 包含 root@%" yes "$(printf '%s' "$out" | grep -q "to 'root'@'%' identified by '88888888'" && echo yes || echo no)"
chk "init_sql 包含 FLUSH 语句" yes "$(printf '%s' "$out" | grep -qi 'flush privileges' && echo yes || echo no)"
chk "init_sql 条件删除匿名用户" yes "$(printf '%s' "$out" | grep -qi 'delete from mysql.user where' && echo yes || echo no)"
chk "init_sql 所有 DELETE 语句均有条件" no "$(printf '%s' "$out" | grep -qiE 'delete from mysql.user;[[:space:]]*$' && echo yes || echo no)"

# mysql_render_init_sql: 密码单引号转义
out=$(mysql_render_init_sql "a'b")
chk "init_sql 转义单引号" yes "$(printf '%s' "$out" | grep -qF "identified by 'a''b'" && echo yes || echo no)"

# mysql_jemalloc_lib: 默认路径 + MYSQL_JEMALLOC_LIB 覆盖
chk "jemalloc 默认路径" "/usr/lib/libjemalloc.so.2" "$(mysql_jemalloc_lib)"
chk "jemalloc env 覆盖默认路径" "/x/lib.so" "$(MYSQL_JEMALLOC_LIB=/x/lib.so mysql_jemalloc_lib)"

# mysql_init_method: mysql 5.0/5.1 使用 install-db, 其它版本使用 initialize-insecure
chk "method 5.0" install-db "$(mysql_init_method 'mysqld  Ver 5.0.95 ...')"
chk "method 5.1" install-db "$(mysql_init_method 'mysqld  Ver 5.1.73 ...')"
chk "method 5.7" initialize-insecure "$(mysql_init_method 'mysqld  Ver 5.7.44 for linux')"

# mysql_write_init_sql: 内容与权限
mysql_write_init_sql "$WORK/sub/init.sql" "secret" >/dev/null 2>&1
chk "write 文件存在" yes "$([ -f "$WORK/sub/init.sql" ] && echo yes || echo no)"
chk "write 含 GRANT" yes "$(grep -q "identified by 'secret'" "$WORK/sub/init.sql" && echo yes || echo no)"
chk "write 权限 600" 600 "$(stat -c %a "$WORK/sub/init.sql" 2>/dev/null)"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
