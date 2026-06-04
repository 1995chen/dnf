#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/dnf-bootstrap.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
failed=0
chk() {
    if [ "$2" = "$3" ]; then pass=$((pass + 1)); else
        printf 'FAIL %-36s want=%s got=%s\n' "$1" "$2" "$3"
        failed=1
    fi
}

mkstub() {
    printf '#!/bin/bash\nexit %s\n' "$2" >"$WORK/$1.sh"
    chmod +x "$WORK/$1.sh"
}

run() {
    mkstub 10-env-resolve "$1"
    mkstub 20-cleanup "$2"
    mkstub 30-init-data "$3"
    mkstub 30-init-db "$4"
    DNF_INIT_PATH="$WORK" bash "$TARGET" >"$WORK/out" 2>&1
    echo $?
}
has() { grep -q "$1" "$WORK/out" && echo yes || echo no; }

chk "全部成功 -> 0" 0 "$(run 0 0 0 0)"
chk "打印完成日志" yes "$(has 'all init steps done')"
chk "10 失败" 1 "$(run 1 0 0 0)"
chk "20 失败" 1 "$(run 0 1 0 0)"
chk "30 失败" 1 "$(run 0 0 1 0)"
chk "30 失败打印失败日志" yes "$(has 'parallel init failed')"
chk "30-init-db 失败" 1 "$(run 0 0 0 1)"
chk "30 全部失败" 1 "$(run 0 0 1 1)"

mkstub_daemon() {
    printf '#!/bin/bash\nsleep 2 </dev/null >/dev/null 2>&1 &\nexit %s\n' "$2" >"$WORK/$1.sh"
    chmod +x "$WORK/$1.sh"
}
mkstub_leak() {
    printf '#!/bin/bash\nsleep 10 &\nexit %s\n' "$2" >"$WORK/$1.sh"
    chmod +x "$WORK/$1.sh"
}
run_daemon() {
    mkstub 10-env-resolve 0
    mkstub 20-cleanup 0
    mkstub 30-init-data 0
    "$1" 30-init-db 0
    timeout 8 env DNF_INIT_PATH="$WORK" bash "$TARGET" >"$WORK/out" 2>&1
    echo $?
}
chk "屏蔽终端输入的 mysqld 正常退出" 0 "$(run_daemon mkstub_daemon)"
chk "屏蔽终端输入的 mysqld 超时" 124 "$(run_daemon mkstub_leak)"

# 脚本日志加 [标签] 前缀
mkstub_out() {
    printf '#!/bin/bash\necho "%s"\nexit 0\n' "$2" >"$WORK/$1.sh"
    chmod +x "$WORK/$1.sh"
}
mkstub 10-env-resolve 0
mkstub 20-cleanup 0
mkstub_out 30-init-data hello-data
mkstub_out 30-init-db hello-db
DNF_INIT_PATH="$WORK" bash "$TARGET" >"$WORK/out" 2>&1
chk "data 前缀" yes "$(has '\[data\] hello-data')"
chk "db 前缀" yes "$(has '\[db\] hello-db')"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
