#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/on-start"
RCD="${SCRIPT_PATH}/../s6-rc.d"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
failed=0
chk() {
    if [ "$2" = "$3" ]; then pass=$((pass + 1)); else
        printf 'FAIL %-40s expected=[%s] got=[%s]\n' "$1" "$2" "$3"
        failed=$((failed + 1))
    fi
}

echo "== 传入服务名: 打印 starting 日志 =="
DNF_SVC_NOTIFY_TARGET="$WORK/out" bash "$TARGET" channel
chk "输出包含服务名的 starting 日志" "[svc] channel starting" "$(cat "$WORK/out")"

echo "== 不传服务字: 默认使用 unknown =="
DNF_SVC_NOTIFY_TARGET="$WORK/out" bash "$TARGET"
chk "不传服务名则使用 unknown" "[svc] unknown starting" "$(cat "$WORK/out")"

echo "== 所有 longrun 服务的 run 脚本都调用 on-start =="
missing=""
for d in "$RCD"/*/; do
    r="$d/run"
    [ -f "$r" ] || continue
    grep -q 'on-start' "$r" || missing="$missing $(basename "$d")"
done
chk "所有 run 都调用 on-start" "" "$missing"

echo "== game_template 用占位符, stage2-hook 替换为实际频道 =="
chk "game_template 用 __SVC_NAME__" yes \
    "$(grep -q 'on-start __SVC_NAME__' "$RCD/game_template/run" && echo yes || echo no)"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
