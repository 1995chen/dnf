#!/bin/bash
# probe-port.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROBE="${SCRIPT_PATH}/probe-port.sh"

if ! command -v socat >/dev/null 2>&1; then
    echo "probe-port.test: socat is required but not installed" >&2
    exit 1
fi

WORK=$(mktemp -d)
LISTENERS=()
cleanup() {
    local p
    for p in "${LISTENERS[@]}"; do kill "$p" 2>/dev/null; done
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

free_port() {
    local p i
    for i in $(seq 1 100); do
        p=$(((RANDOM % 40000) + 20000))
        socat -T1 /dev/null "TCP:127.0.0.1:$p" >/dev/null 2>&1 ||
            { printf '%s' "$p"; return 0; }
    done
    printf '%s' "$p"
}
listen_on() {
    socat "TCP-LISTEN:$1,reuseaddr,fork" /dev/null >/dev/null 2>&1 &
    LISTENERS+=("$!")
    local i
    for i in $(seq 1 50); do
        socat -T1 /dev/null "TCP:127.0.0.1:$1" >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "listen_on: port $1 did not come up" >&2
    exit 1
}

# 用法:
# mkcfg <文件> <原始行内容>
mkcfg() {
    printf 'some_key = 1\n%s\nother = x\n' "$2" >"$1"
}

P=$(free_port)
echo "== port read from cfg, connect succeeds when listening =="
mkcfg "$WORK/ok.cfg" "this_tcp_port = $P"
listen_on "$P"
ok "listening port -> success" bash "$PROBE" "$WORK/ok.cfg"
ok "explicit host arg works" bash "$PROBE" "$WORK/ok.cfg" 127.0.0.1
ok "empty host arg falls back to local" bash "$PROBE" "$WORK/ok.cfg" ""

echo "== nothing listening / bad cfg -> fail =="
DP=$(free_port)
mkcfg "$WORK/dead.cfg" "this_tcp_port = $DP"
no "no listener -> fail" bash "$PROBE" "$WORK/dead.cfg"
no "missing cfg -> fail" bash "$PROBE" "$WORK/nope.cfg"
printf 'no port here\n' >"$WORK/noport.cfg"
no "cfg without this_tcp_port -> fail" bash "$PROBE" "$WORK/noport.cfg"
mkcfg "$WORK/bad.cfg" "this_tcp_port = abc"
no "non-numeric port -> fail" bash "$PROBE" "$WORK/bad.cfg"

echo "== whitespace tolerance in cfg line =="
P2=$(free_port)
printf '   this_tcp_port=%s   \n' "$P2" >"$WORK/ws.cfg"
listen_on "$P2"
ok "no spaces around = tolerated" bash "$PROBE" "$WORK/ws.cfg"
P3=$(free_port)
printf 'this_tcp_port\t=\t%s\n' "$P3" >"$WORK/tab.cfg"
listen_on "$P3"
ok "tabs around = tolerated" bash "$PROBE" "$WORK/tab.cfg"

echo "== cfg path with spaces + Chinese =="
sp="$WORK/配 置 目录"
mkdir -p "$sp"
P4=$(free_port)
mkcfg "$sp/server.cfg" "this_tcp_port = $P4"
listen_on "$P4"
ok "spaced+Chinese cfg path" bash "$PROBE" "$sp/server.cfg"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
