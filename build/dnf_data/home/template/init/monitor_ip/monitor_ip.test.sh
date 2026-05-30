#!/bin/bash
# monitor_ip.sh handle_ip_change 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../lib" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
calls_file="$WORK/calls"
bin_path="$WORK/bin"

mkdir -p "$bin_path"
for cmd in s6-rc s6-svc killall; do
    cat >"$bin_path/$cmd" <<EOF
#!/bin/bash
echo "$cmd \$*" >>"$calls_file"
EOF
    chmod +x "$bin_path/$cmd"
done
export PATH="$bin_path:$PATH"

export DNF_LIB_PATH="$LIB_PATH"
export MONITOR_IP_STATE_FILE="$WORK/state"
# shellcheck source=/dev/null
source "${SCRIPT_PATH}/monitor_ip.sh"

kill_graceful() { echo "kill_graceful $*" >>"$calls_file"; }
wait_for_port() {
    echo "wait_for_port $*" >>"$calls_file"
    return 0
}
sleep() { :; }

export MAIN_BRIDGE_IP=""
failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-36s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}
exists() { [ -e "$1" ] && echo yes || echo no; }
count() { grep -c -- "$1" "$calls_file" 2>/dev/null || true; }

# IP 为空时返回 1, 不写状态文件, 不重启
: >"$calls_file"
rm -f "$MONITOR_IP_STATE_FILE"
handle_ip_change "" "test" 1
chk "空IP返回1" 1 "$?"
chk "空IP不写状态文件" no "$(exists "$MONITOR_IP_STATE_FILE")"
chk "空IP不调用s6-rc" 0 "$(count 's6-rc')"

# IP 不变时返回 0, 不重启服务, 不改状态文件
echo "1.2.3.4" >"$MONITOR_IP_STATE_FILE"
: >"$calls_file"
handle_ip_change "1.2.3.4" "test" 1
chk "IP未变返回0" 0 "$?"
chk "IP未变时不重启服务" 0 "$(count 's6-rc')"
chk "IP未变时不改状态文件" "1.2.3.4" "$(cat "$MONITOR_IP_STATE_FILE")"

# IP 变化且无MAIN_BRIDGE_IP时，写入新IP到状态文件, 重启 dnf-channel + llnut gate, 不重启 dnf-bridge
echo "1.2.3.4" >"$MONITOR_IP_STATE_FILE"
: >"$calls_file"
export MAIN_BRIDGE_IP=""
handle_ip_change "5.6.7.8" "test" 1
chk "IP变化时返回0" 0 "$?"
chk "IP变化时写入新IP" "5.6.7.8" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "IP变化时停止dnf-channel" 1 "$(count 's6-rc -d change dnf-channel')"
chk "IP变化时启动dnf-channel" 1 "$(count 's6-rc -u change dnf-channel')"
chk "IP变化时重启 llnut 登录器网关" 1 "$(count 's6-svc -r /run/service/llnut_gate')"
chk "IP变化时优雅关闭bridge和channel" 1 "$(count 'kill_graceful 3 df_bridge_r df_channel_r')"
chk "IP变化时强杀game进程" 1 "$(count 'killall -9 df_game_r')"
chk "无MAIN_BRIDGE_IP时不重启dnf-bridge" 0 "$(count 'dnf-bridge')"

# IP 变化且有MAIN_BRIDGE_IP时，写入新IP到状态文件, 重启 dnf-bridge
echo "1.1.1.1" >"$MONITOR_IP_STATE_FILE"
: >"$calls_file"
export MAIN_BRIDGE_IP="10.0.0.1"
handle_ip_change "2.2.2.2" "test" 1
chk "有MAIN_BRIDGE_IP时停止dnf-bridge" 1 "$(count 's6-rc -d change dnf-bridge')"
chk "有MAIN_BRIDGE_IP时启动dnf-bridge" 1 "$(count 's6-rc -u change dnf-bridge')"
chk "有MAIN_BRIDGE_IP时等待bridge端口监听" 1 "$(count 'wait_for_port 10.0.0.1 7000 30')"
chk "有MAIN_BRIDGE_IP时重启dnf-channel" 1 "$(count 's6-rc -u change dnf-channel')"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
