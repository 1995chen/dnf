#!/bin/bash
# probe-zerg-listen.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROBE="${SCRIPT_PATH}/probe-zerg-listen.sh"

if ! command -v socat >/dev/null 2>&1; then
    echo "probe-zerg-listen.test: socat is required but not installed" >&2
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

# 用法: mkzerg <文件> <self_type> <self_id>
mkzerg() {
    printf '<zerg_config>\n\t<self_cfg>\n\t\t<self_svr_info>\n\t\t\t<svr_type>%s</svr_type>\n\t\t\t<svr_id>%s</svr_id>\n\t\t\t<use_encrypt>0x0</use_encrypt>\n\t\t</self_svr_info>\n\t</self_cfg>\n</zerg_config>\n' "$2" "$3" >"$1"
}
# 用法: mksvcid <文件> <type> <id> <port> [<type> <id> <port> ...]
mksvcid() {
    local out="$1"
    shift
    printf '<svcid_config>\n' >"$out"
    while [ "$#" -ge 3 ]; do
        printf '\t<service_info_>\n\t\t<svr_type_> %s </svr_type_>\n\t\t<svr_id_> %s </svr_id_>\n\t\t<svr_ip_> 127.0.0.1 </svr_ip_>\n\t\t<svr_port_> %s </svr_port_>\n\t</service_info_>\n' "$1" "$2" "$3" >>"$out"
        shift 3
    done
    printf '</svcid_config>\n' >>"$out"
}

listen_on
P=$BOUND_PORT
DP=$(free_port)

echo "== (type,id) 从 svcid.xml 中成功解析得到端口，且该端口成功监听: 就绪 =="
mkzerg "$WORK/zerg.xml" 30 570011
mksvcid "$WORK/svcid.xml" 31 570001 "$DP" 2 1 "$DP" 30 999999 "$DP" 30 570011 "$P"
ok "(30,570011) 解析成功" bash "$PROBE" "$WORK/zerg.xml" "$WORK/svcid.xml"
ok "自定义 host 参数" bash "$PROBE" "$WORK/zerg.xml" "$WORK/svcid.xml" 127.0.0.1

echo "== xml 标签带属性不应该获取到属性值 =="
{
    printf '<zerg_config>\n\t<self_cfg>\n\t\t<self_svr_info>\n'
    printf '\t\t\t<svr_type foo="1">30</svr_type>\n'
    printf '\t\t\t<svr_id bar="2">570011</svr_id>\n'
    printf '\t\t</self_svr_info>\n\t</self_cfg>\n</zerg_config>\n'
} >"$WORK/zatt.xml"
{
    printf '<svcid_config>\n\t<service_info_>\n'
    printf '\t\t<svr_type_ a="9"> 30 </svr_type_>\n'
    printf '\t\t<svr_id_ b="8"> 570011 </svr_id_>\n'
    printf '\t\t<svr_port_ c="7"> %s </svr_port_>\n' "$P"
    printf '\t</service_info_>\n</svcid_config>\n'
} >"$WORK/satt.xml"
ok "属性值未被获取" bash "$PROBE" "$WORK/zatt.xml" "$WORK/satt.xml"

echo "== 同类型不同 id 不应被错误匹配 =="
mksvcid "$WORK/wrongid.xml" 30 999999 "$P" 30 570011 "$DP"
no "按 id 区分, 不获取同类型其它 id 的端口" bash "$PROBE" "$WORK/zerg.xml" "$WORK/wrongid.xml"

echo "== 当缺少 svr_id_，不会匹配到上一次残留的 id =="
{
    printf '<svcid_config>\n'
    printf '\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_id_> 570011 </svr_id_>\n\t\t<svr_port_> %s </svr_port_>\n\t</service_info_>\n' "$DP"
    printf '\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_port_> %s </svr_port_>\n\t</service_info_>\n' "$P"
    printf '</svcid_config>\n'
} >"$WORK/leak.xml"
no "缺 svr_id_ 的块不匹配上一次残留的 id" bash "$PROBE" "$WORK/zerg.xml" "$WORK/leak.xml"

echo "== 缺失或匹配失败: 未就绪 =="
mksvcid "$WORK/none.xml" 2 1 "$DP"
no "svcid.xml 未匹配 (type,id): 未就绪" bash "$PROBE" "$WORK/zerg.xml" "$WORK/none.xml"
no "zergsvrd.xml 不存在: 未就绪" bash "$PROBE" "$WORK/nope.xml" "$WORK/svcid.xml"
no "svcid.xml 不存在: 未就绪" bash "$PROBE" "$WORK/zerg.xml" "$WORK/nope.xml"
printf '<zerg_config>\n\t<comm_cfg>\n\t\t<send_pipe_len>1</send_pipe_len>\n\t</comm_cfg>\n</zerg_config>\n' >"$WORK/noself.xml"
no "zergsvrd.xml 无 self_svr_info: 未就绪" bash "$PROBE" "$WORK/noself.xml" "$WORK/svcid.xml"
no "缺少参数: 未就绪" bash "$PROBE" "$WORK/zerg.xml"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
