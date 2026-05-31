#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
RESTORE="${SCRIPT_PATH}/restore-db.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-44s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}

# 解析后的库连接信息，模拟 /run/s6/container_environment
envd="$WORK/env"
mkdir -p "$envd"
printf '127.0.0.1' >"$envd/CUR_SG_DB_HOST"
printf '4000' >"$envd/CUR_SG_DB_PORT"
printf 'secret' >"$envd/CUR_SG_DB_ROOT_PASSWORD"

bk="$WORK/backup"
mkdir -p "$bk"
echo "CREATE DATABASE IF NOT EXISTS d_taiwan;" | gzip >"$bk/dnf-20260101-000000.sql.gz"
echo "CREATE DATABASE IF NOT EXISTS d_taiwan;" | gzip >"$bk/dnf-20260102-000000.sql.gz"

stubdir="$WORK/bin"
mkdir -p "$stubdir"
cat >"$stubdir/mysql" <<'EOF'
#!/bin/bash
cat >/dev/null
echo "called" >>"$MYSQL_CALL_LOG"
EOF
chmod +x "$stubdir/mysql"

run() {
    CONTAINER_ENV_PATH="$envd" DB_BACKUP_DIR="$bk" \
        PATH="$stubdir:$PATH" MYSQL_CALL_LOG="$WORK/mysql.log" "$@"
}
# 判断退出码, 输出 yes/no, 避免用 $?
exits_nonzero() { if "$@" >/dev/null 2>&1; then echo no; else echo yes; fi; }

: >"$WORK/mysql.log"
out=$(run bash "$RESTORE" latest 2>&1)
chk "恢复计划-使用最新备份文件" yes "$(echo "$out" | grep -q "dnf-20260102-000000" && echo yes || echo no)"
chk "恢复计划-不调用 mysql" 0 "$(grep -c . "$WORK/mysql.log")"
chk "恢复计划-提示 DRY-RUN" yes "$(echo "$out" | grep -q "DRY-RUN" && echo yes || echo no)"

# 真实恢复
: >"$WORK/mysql.log"
run env DB_RESTORE_CONFIRM=yes bash "$RESTORE" latest >/dev/null 2>&1
chk "真实恢复-调用 mysql" 1 "$(grep -c . "$WORK/mysql.log")"

# 按文件名选择
out=$(run bash "$RESTORE" dnf-20260101-000000.sql.gz 2>&1)
chk "按文件名-选择指定备份文件" yes "$(echo "$out" | grep -q "dnf-20260101-000000" && echo yes || echo no)"

# 文件不存在，返回非0退出码
chk "文件不存在-返回非0退出码" yes "$(exits_nonzero run bash "$RESTORE" nope.sql.gz)"

# 连接信息不完整: 返回非0退出码
empty="$WORK/empty"
mkdir -p "$empty"
chk "连接信息不完整-返回非0退出码" yes \
    "$(exits_nonzero env CONTAINER_ENV_PATH="$empty" DB_BACKUP_DIR="$bk" \
        PATH="$stubdir:$PATH" DB_RESTORE_CONFIRM=yes bash "$RESTORE" latest)"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
