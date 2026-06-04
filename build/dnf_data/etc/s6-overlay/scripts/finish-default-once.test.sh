#!/bin/bash

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TARGET="${SCRIPT_PATH}/finish-default-once"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
failed=0

run() {
    local code="$1" sig="$2" pgid="${3:-1}"
    (
        DNF_SVC_NOTIFY_TARGET="$WORK/out" bash "$TARGET" "$code" "$sig" game_siroco52 "$pgid"
    )
    echo "$?" >"$WORK/rc"
}

reset_state() { rm -f "$WORK/out"; }

exit_is() {
    local d="$1" want="$2" got
    got=$(cat "$WORK/rc")
    if [ "$got" = "$want" ]; then pass=$((pass + 1)); else
        printf 'FAIL %-44s (exit want %s got %s)\n' "$d" "$want" "$got"
        failed=$((failed + 1))
    fi
}
out_has() {
    local d="$1" n="$2"
    if grep -qF -- "$n" "$WORK/out"; then pass=$((pass + 1)); else
        printf 'FAIL %-44s (missing %q in: %s)\n' "$d" "$n" "$(cat "$WORK/out")"
        failed=$((failed + 1))
    fi
}

echo "== 正常退出 exit 0: 不重启, 返回 125 =="
reset_state
run 0 0
exit_is "exit0 returns 125" 125
out_has "exit0 message" "stopped (exit 0), no restart"

echo "== 非零退出码: 异常退出, 重启 =="
reset_state
run 1 0
exit_is "code1 returns 0" 0
out_has "code1 message" "exited abnormally (code=1), restarting"

echo "== SIGSEGV(11): 崩溃 =="
reset_state
run 256 11
exit_is "segv returns 0" 0
out_has "segv message" "crashed (SIGSEGV), restarting"

echo "== SIGABRT(6): 崩溃, 名字统一为 ABRT 而非 IOT =="
reset_state
run 256 6
exit_is "abrt returns 0" 0
out_has "abrt message" "crashed (SIGABRT), restarting"

echo "== SIGTERM(15) =="
reset_state
run 256 15
exit_is "term returns 0" 0
out_has "term message" "killed by SIGTERM, restarting"

echo "== SIGKILL(9) =="
reset_state
run 256 9
exit_is "kill returns 0" 0
out_has "kill message" "killed by SIGKILL, restarting"

echo "== kill 时清理进程组下其他进程 (kill -9 -- -\$4) =="
reset_state
setsid sh -c 'exec sleep 300' &
leader=$!
disown 2>/dev/null || true
ready=0
for _ in $(seq 1 20); do
    kill -0 "$leader" 2>/dev/null && {
        ready=1
        break
    }
    sleep 0.1
done
pgid=$(ps -o pgid= -p "$leader" 2>/dev/null | tr -d ' ')
[ -n "$pgid" ] || pgid="$leader"
if [ "$ready" = 1 ] && [ "$pgid" != 1 ]; then
    run 256 9 "$pgid"
    exit_is "cleanup returns 0" 0
    out_has "cleanup message" "killed by SIGKILL, restarting"
    dead=0
    for _ in $(seq 1 20); do
        kill -0 "$leader" 2>/dev/null || {
            dead=1
            break
        }
        sleep 0.1
    done
    if [ "$dead" = 1 ]; then pass=$((pass + 1)); else
        printf 'FAIL %-44s (victim survived process-group kill)\n' "orphan cleanup"
        failed=$((failed + 1))
        kill -9 "$leader" 2>/dev/null
    fi
else
    echo "SKIP orphan cleanup: could not set up isolated victim"
fi

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
