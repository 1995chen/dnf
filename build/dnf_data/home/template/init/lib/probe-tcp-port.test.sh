#!/bin/bash
# probe-tcp-port.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROBE="${SCRIPT_PATH}/probe-tcp-port.sh"

if ! command -v socat >/dev/null 2>&1; then
    echo "probe-tcp-port.test: socat is required but not installed" >&2
    exit 1
fi
WORK=$(mktemp -d)
LISTENERS=()
cleanup() {
    local p
    for p in "${LISTENERS[@]}"; do
        pkill -P "$p" 2>/dev/null
        kill "$p" 2>/dev/null
    done
    wait 2>/dev/null
    rm -rf "$WORK"
}
trap cleanup EXIT

failed=0
pass=0
ok() {
    local desc="$1"
    shift
    if "$@"; then pass=$((pass + 1)); else
        printf "FAIL %-52s (expected exit 0)\n" "$desc"
        failed=$((failed + 1))
    fi
}
no() {
    local desc="$1"
    shift
    if "$@"; then
        printf "FAIL %-52s (expected non-zero exit)\n" "$desc"
        failed=$((failed + 1))
    else pass=$((pass + 1)); fi
}

_listener_port() {
    local pid="$1" fd target inode hex
    for fd in /proc/"$pid"/fd/*; do
        target=$(readlink "$fd" 2>/dev/null) || continue
        case "$target" in
        socket:\[*\]) ;;
        *) continue ;;
        esac
        inode=${target//[^0-9]/}
        [ -n "$inode" ] || continue
        hex=$(awk -v ino="$inode" '$4 == "0A" && $10 == ino { split($2, a, ":"); print a[2]; exit }' /proc/net/tcp 2>/dev/null)
        [ -n "$hex" ] && {
            printf '%s' "$((16#$hex))"
            return 0
        }
    done
    return 1
}
_wait_listen() {
    local pid="$1" port _
    for _ in $(seq 1 100); do
        kill -0 "$pid" 2>/dev/null || return 1
        port=$(_listener_port "$pid")
        [ -n "$port" ] && {
            printf '%s' "$port"
            return 0
        }
        sleep 0.1
    done
    return 1
}
listen_on() {
    socat "TCP4-LISTEN:0,reuseaddr,fork" /dev/null >/dev/null 2>&1 &
    local pid=$! port
    if ! port=$(_wait_listen "$pid"); then
        kill "$pid" 2>/dev/null
        echo "listen_on: failed to bring up a socat listener" >&2
        exit 1
    fi
    LISTENERS+=("$pid")
    BOUND_PORT="$port"
}
free_port() {
    socat "TCP4-LISTEN:0,reuseaddr,fork" /dev/null >/dev/null 2>&1 &
    local pid=$! port _
    port=$(_wait_listen "$pid")
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    if [ -n "$port" ]; then
        for _ in $(seq 1 50); do
            socat -T1 /dev/null "TCP4:127.0.0.1:${port},connect-timeout=1" >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi
    printf '%s' "$port"
}

listen_on
P=$BOUND_PORT
DP=$(free_port)

echo "== 端口变量已设置且端口正在监听: 就绪 =="
ok "端口变量与监听端口一致" env PROXY_PORT="$P" bash "$PROBE" PROXY_PORT
ok "自定义 host 参数" env PROXY_PORT="$P" bash "$PROBE" PROXY_PORT 127.0.0.1

echo "== 端口变量为空或未定义: 就绪 =="
ok "变量为空: 就绪" env PROXY_PORT= bash "$PROBE" PROXY_PORT
ok "变量未定义: 就绪" env -u PROXY_PORT bash "$PROBE" PROXY_PORT

echo "== 端口变量已设但端口未监听: 未就绪 =="
no "端口未监听: 未就绪" env PROXY_PORT="$DP" bash "$PROBE" PROXY_PORT

echo "== 参数错误: 未就绪 =="
no "非数字端口: 未就绪" env PROXY_PORT=abc bash "$PROBE" PROXY_PORT
no "缺少参数: 未就绪" bash "$PROBE"
no "变量名非法: 未就绪" bash "$PROBE" "a-b"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
