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

# 获取 socat 监听的端口
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
        # /proc/net/tcp: $2=本地地址 HEXIP:HEXPORT, $4=状态(0A=LISTEN), $10=inode
        hex=$(awk -v ino="$inode" '$4 == "0A" && $10 == ino { split($2, a, ":"); print a[2]; exit }' /proc/net/tcp 2>/dev/null)
        [ -n "$hex" ] && {
            printf '%s' "$((16#$hex))"
            return 0
        }
    done
    return 1
}

# 轮询等待 socat 监听完成，之后通过 stdout 返回监听的端口
# 超时或进程退出返回 1
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

# 用法:
# mkcfg <文件> <原始行内容>
mkcfg() {
    printf 'some_key = 1\n%s\nother = x\n' "$2" >"$1"
}

listen_on
P=$BOUND_PORT
echo "== port read from cfg, connect succeeds when listening =="
mkcfg "$WORK/ok.cfg" "this_tcp_port = $P"
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
listen_on
P2=$BOUND_PORT
printf '   this_tcp_port=%s   \n' "$P2" >"$WORK/ws.cfg"
ok "no spaces around = tolerated" bash "$PROBE" "$WORK/ws.cfg"
listen_on
P3=$BOUND_PORT
printf 'this_tcp_port\t=\t%s\n' "$P3" >"$WORK/tab.cfg"
ok "tabs around = tolerated" bash "$PROBE" "$WORK/tab.cfg"

echo "== cfg path with spaces + Chinese =="
sp="$WORK/配 置 目录"
mkdir -p "$sp"
listen_on
P4=$BOUND_PORT
mkcfg "$sp/server.cfg" "this_tcp_port = $P4"
ok "spaced+Chinese cfg path" bash "$PROBE" "$sp/server.cfg"

echo "== custom port-field, tcp_port for dbmw =="
listen_on
P5=$BOUND_PORT
printf 'tcp_port = %s\nudp_port = 1\n' "$P5" >"$WORK/dbmw.cfg"
ok "custom field tcp_port -> success" bash "$PROBE" "$WORK/dbmw.cfg" 127.0.0.1 tcp_port
no "default field misses tcp_port cfg" bash "$PROBE" "$WORK/dbmw.cfg"
no "invalid field rejected" bash "$PROBE" "$WORK/ok.cfg" 127.0.0.1 "a/b"

echo "== numbered prefix + whitespace separator =="
listen_on
P6=$BOUND_PORT
{
    printf '1.Define_Tick_Count_Value\t30\n'
    printf '2.Define_Server_UDP_Port           40404\n'
    printf '4.Define_Server_TCP_Port           %s\n' "$P6"
} >"$WORK/capp.cfg"
ok "numbered+whitespace TCP field" bash "$PROBE" "$WORK/capp.cfg" 127.0.0.1 Define_Server_TCP_Port

listen_on
P7=$BOUND_PORT
{
    printf 'this_tcp_port = 11111\n'
    printf 'tcp_port_of_guild = 22222\n'
    printf 'tcp_port = %s // listen port\n' "$P7"
} >"$WORK/sib.cfg"
ok "tcp_port skips this_tcp_port/tcp_port_of_* and // comment" bash "$PROBE" "$WORK/sib.cfg" 127.0.0.1 tcp_port

echo "== 端口占位符未替换 =="
printf 'this_tcp_port = 7ABC00\n' >"$WORK/placeholder.cfg"
no "partial-numeric value rejected" bash "$PROBE" "$WORK/placeholder.cfg"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
