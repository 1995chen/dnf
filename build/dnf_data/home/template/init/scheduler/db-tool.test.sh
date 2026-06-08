#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TOOL="${SCRIPT_PATH}/db-tool.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-48s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}
# 判断退出码, 输出 yes/no, 避免用 $?
exits_nonzero() { if "$@" >/dev/null 2>&1; then echo no; else echo yes; fi; }

# 模拟 /run/s6/container_environment 的连接信息
envd="$WORK/env"
mkdir -p "$envd"
printf '127.0.0.1' >"$envd/CUR_SG_DB_HOST"
printf '4000' >"$envd/CUR_SG_DB_PORT"
printf 'rootpw' >"$envd/CUR_SG_DB_ROOT_PASSWORD"
printf 'gamepw' >"$envd/DNF_DB_GAME_PASSWORD"

stub="$WORK/bin"
mkdir -p "$stub"
cat >"$stub/mysql" <<'EOF'
#!/bin/bash
case "$*" in
*"SHOW DATABASES"*)
    printf 'information_schema\nmysql\nd_taiwan\ntaiwan_cain\n'
    ;;
*)
    cat >/dev/null
    echo called >>"$MYSQL_CALL_LOG"
    if [ "${MYSQL_FAIL:-}" = yes ]; then exit 1; fi
    ;;
esac
EOF
cat >"$stub/mysqldump" <<'EOF'
#!/bin/bash
echo "$*" >>"$MYSQLDUMP_ARG_LOG"
if [ "${MYSQLDUMP_FAIL:-}" = yes ]; then
    echo "ERROR: simulated dump failure" >&2
    exit 2
fi
echo "CREATE DATABASE IF NOT EXISTS d_taiwan;"
echo "-- simulated dump"
EOF
chmod +x "$stub/mysql" "$stub/mysqldump"

bk="$WORK/backup"
run() {
    CONTAINER_ENV_PATH="$envd" DB_BACKUP_DIR="$bk" PATH="$stub:$PATH" \
        MYSQL_CALL_LOG="$WORK/mysql.log" MYSQLDUMP_ARG_LOG="$WORK/dump.args" "$@"
}

# 备份
rm -rf "$bk"
: >"$WORK/dump.args"
run bash "$TOOL" backup >/dev/null 2>&1
chk "备份: 生成一个备份文件" 1 "$(find "$bk" -name 'dnf-*.sql.gz' 2>/dev/null | wc -l)"
chk "备份: 导出 d_taiwan 库" yes "$(grep -qw d_taiwan "$WORK/dump.args" && echo yes || echo no)"
chk "备份: 导出 taiwan_cain 库" yes "$(grep -qw taiwan_cain "$WORK/dump.args" && echo yes || echo no)"
chk "备份: 过滤 information_schema 库" no "$(grep -qw information_schema "$WORK/dump.args" && echo yes || echo no)"
chk "备份: 过滤 mysql 库" no "$(grep -qw mysql "$WORK/dump.args" && echo yes || echo no)"

# 备份失败删除损坏文件
rm -rf "$bk"
run env MYSQLDUMP_FAIL=yes bash "$TOOL" backup >/dev/null 2>&1
chk "备份失败不保留损坏文件" 0 "$(find "$bk" -name 'dnf-*.sql.gz' 2>/dev/null | wc -l)"

# 只保留 KEEP 份
rm -rf "$bk"
mkdir -p "$bk"
for t in 20260101-000000 20260102-000000 20260103-000000; do
    echo x | gzip >"$bk/dnf-$t.sql.gz"
done
run env DB_BACKUP_KEEP=2 bash "$TOOL" backup >/dev/null 2>&1
chk "成功备份后只保留 KEEP 份" 2 "$(find "$bk" -name 'dnf-*.sql.gz' | wc -l)"

# 恢复
rm -rf "$bk"
mkdir -p "$bk"
echo "CREATE DATABASE IF NOT EXISTS d_taiwan;" | gzip >"$bk/dnf-20260101-000000.sql.gz"
echo "CREATE DATABASE IF NOT EXISTS d_taiwan;" | gzip >"$bk/dnf-20260102-000000.sql.gz"

: >"$WORK/mysql.log"
out=$(run bash "$TOOL" restore latest 2>&1)
chk "恢复计划: 使用最新备份文件" yes "$(echo "$out" | grep -q "dnf-20260102-000000" && echo yes || echo no)"
chk "恢复计划: 不调用 mysql" 0 "$(grep -c . "$WORK/mysql.log")"
chk "恢复计划: 提示 DRY-RUN" yes "$(echo "$out" | grep -q "DRY-RUN" && echo yes || echo no)"

: >"$WORK/mysql.log"
out=$(run env DB_RESTORE_CONFIRM=yes bash "$TOOL" restore latest 2>&1)
chk "真实恢复: 调用 mysql" 1 "$(grep -c . "$WORK/mysql.log")"
chk "真实恢复: 提示重启服务端" yes "$(echo "$out" | grep -qi "restart the container" && echo yes || echo no)"

# 当 gzip 解压成功但 mysql 执行失败时应返回非0, 防止 PIPESTATUS 误判为成功
chk "恢复-mysql 失败返回非0" yes \
    "$(exits_nonzero run env DB_RESTORE_CONFIRM=yes MYSQL_FAIL=yes bash "$TOOL" restore latest)"

out=$(run bash "$TOOL" restore dnf-20260101-000000.sql.gz 2>&1)
chk "恢复: 按文件名选择指定备份文件" yes "$(echo "$out" | grep -q "dnf-20260101-000000" && echo yes || echo no)"

chk "恢复: 文件不存在返回非0" yes "$(exits_nonzero run bash "$TOOL" restore nope.sql.gz)"

empty="$WORK/empty"
mkdir -p "$empty"
chk "恢复: 连接信息不完整返回非0" yes \
    "$(exits_nonzero env CONTAINER_ENV_PATH="$empty" DB_BACKUP_DIR="$bk" \
        PATH="$stub:$PATH" DB_RESTORE_CONFIRM=yes bash "$TOOL" restore latest)"

chk "无子命令返回非0" yes "$(exits_nonzero run bash "$TOOL")"
chk "未知子命令返回非0" yes "$(exits_nonzero run bash "$TOOL" frobnicate)"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
