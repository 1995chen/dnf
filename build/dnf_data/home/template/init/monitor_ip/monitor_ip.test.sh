#!/bin/bash
# monitor_ip.sh handle_ip_change 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../lib" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
calls_file="$WORK/calls"
bin_path="$WORK/bin"
fail_file="$WORK/s6rc_fail"
othererr_file="$WORK/s6rc_othererr"
hardfail_file="$WORK/s6rc_hardfail"

mkdir -p "$bin_path"
cat >"$bin_path/s6-rc" <<EOF
#!/bin/bash
echo "s6-rc \$*" >>"$calls_file"
if [ -e "$othererr_file" ]; then
    echo "s6-rc: fatal: unknown service" >&2
    exit 1
fi
if [ -s "$hardfail_file" ]; then
    pat=\$(cat "$hardfail_file")
    case "\$*" in
    *"\$pat"*)
        echo "s6-rc: fatal: timed out" >&2
        exit 1
        ;;
    esac
fi
if [ -s "$fail_file" ]; then
    n=\$(cat "$fail_file")
    if [ "\$n" -gt 0 ]; then
        echo \$((n - 1)) >"$fail_file"
        echo "s6-rc: fatal: unable to take locks: Resource busy" >&2
        exit 1
    fi
fi
exit 0
EOF
chmod +x "$bin_path/s6-rc"
running_file="$WORK/running"
: >"$running_file"
cat >"$bin_path/pgrep" <<EOF
#!/bin/bash
shift \$(( \$# - 1 ))
grep -qxF "\$1" "$running_file" 2>/dev/null
EOF
chmod +x "$bin_path/pgrep"
export PATH="$bin_path:$PATH"

set_running() {
    if [ "$#" -eq 0 ]; then
        : >"$running_file"
    else
        printf '%s\n' "$@" >"$running_file"
    fi
}

export DNF_LIB_PATH="$LIB_PATH"
export MONITOR_IP_STATE_FILE="$WORK/state"
export S6RC_LOCK_RETRY=10
# shellcheck source=/dev/null
source "${SCRIPT_PATH}/monitor_ip.sh"

sleep() { :; }

export MAIN_BRIDGE_IP=""
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
exists() { [ -e "$1" ] && echo yes || echo no; }
count() { grep -c -- "$1" "$calls_file" 2>/dev/null || true; }
line_of() { grep -n -- "$1" "$calls_file" 2>/dev/null | head -1 | cut -d: -f1; }
before() {
    local a b
    a=$(line_of "$1")
    b=$(line_of "$2")
    [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && echo yes || echo no
}
setup() {
    : >"$calls_file"
    : >"$fail_file"
    rm -f "$othererr_file" "$hardfail_file"
    set_running
    applied_ip="$1"
    if [ -n "$2" ]; then echo "$2" >"$MONITOR_IP_STATE_FILE"; else rm -f "$MONITOR_IP_STATE_FILE"; fi
    export MAIN_BRIDGE_IP=""
}

setup "" ""
handle_ip_change "" "test" 1
chk "空IP返回1" 1 "$?"
chk "空IP不写state文件" no "$(exists "$MONITOR_IP_STATE_FILE")"
chk "空IP不调用s6-rc" 0 "$(count 's6-rc')"
chk "空IP applied_ip不变" "" "$applied_ip"

# 首次解析(applied_ip为空): 写入state文件+更新applied_ip, 不重启
setup "" ""
handle_ip_change "9.9.9.9" "domain" 1
chk "首次解析返回0" 0 "$?"
chk "首次解析写入IP" "9.9.9.9" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "首次解析更新applied_ip" "9.9.9.9" "$applied_ip"
chk "首次解析不调用s6-rc" 0 "$(count 's6-rc')"

# IP与applied_ip一致: 不重启, 不更新applied_ip
setup "1.2.3.4" "1.2.3.4"
handle_ip_change "1.2.3.4" "test" 1
chk "IP不变时返回0" 0 "$?"
chk "IP不变时不调用s6-rc" 0 "$(count 's6-rc')"
chk "IP不变时applied_ip不变" "1.2.3.4" "$applied_ip"

# IP变化且MAIN_BRIDGE_IP为空
setup "1.2.3.4" "1.2.3.4"
handle_ip_change "5.6.7.8" "test" 1
chk "IP变化: 成功获取锁返回0" 0 "$?"
chk "IP变化: 写入新IP" "5.6.7.8" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "IP变化: 更新applied_ip" "5.6.7.8" "$applied_ip"
chk "IP变化: 关闭 dnf-channel" 1 "$(count 's6-rc -d change dnf-channel')"
chk "IP变化: 启动 dnf-channel" 1 "$(count 's6-rc -u change dnf-channel')"
chk "IP变化: 关闭 llnut_gate" 1 "$(count 's6-rc -d change llnut_gate')"
chk "IP变化: 启动 llnut_gate" 1 "$(count 's6-rc -u change llnut_gate')"
chk "MAIN_BRIDGE_IP为空时不重启 dnf-bridge" 0 "$(count 'dnf-bridge')"

# IP变化且MAIN_BRIDGE_IP不为空
setup "1.1.1.1" "1.1.1.1"
export MAIN_BRIDGE_IP="10.0.0.1"
handle_ip_change "2.2.2.2" "test" 1
chk "IP变化且MAIN_BRIDGE_IP不为空: 关闭 dnf-bridge" 1 "$(count 's6-rc -d change dnf-bridge')"
chk "IP变化且MAIN_BRIDGE_IP不为空: 启动 dnf-bridge" 1 "$(count 's6-rc -u change dnf-bridge')"
chk "IP变化且MAIN_BRIDGE_IP不为空: 操作顺序: 先执行 u bridge 再执行 u channel" yes "$(before 's6-rc -u change dnf-bridge' 's6-rc -u change dnf-channel')"

# IP变化+锁被占
setup "1.2.3.4" "1.2.3.4"
echo 99 >"$fail_file"
handle_ip_change "7.7.7.7" "test" 1
chk "锁被占用返回0" 0 "$?"
chk "锁被占用state更新为最新" "7.7.7.7" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "锁被占用applied_ip不变" "1.2.3.4" "$applied_ip"
chk "锁被占用仅尝试获取一次锁" 1 "$(count 's6-rc')"
chk "锁被占用不执行 u dnf-channel" 0 "$(count 's6-rc -u change dnf-channel')"

# 容器启动期间IP反复变化，只更新state文件并等待初次启动成功，之后使用最新IP启动（跳过中间的IP）
setup "10.0.0.0" "10.0.0.0"
echo 99 >"$fail_file"
handle_ip_change "10.0.0.1" "domain" 1 # 推迟
chk "IP反复变化-1 state=B" "10.0.0.1" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "IP反复变化-1 applied_ip不变" "10.0.0.0" "$applied_ip"
handle_ip_change "10.0.0.2" "domain" 1 # 推迟
chk "IP反复变化-2 state=C" "10.0.0.2" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "IP反复变化-2 applied_ip不变" "10.0.0.0" "$applied_ip"
: >"$fail_file"
handle_ip_change "10.0.0.3" "domain" 1 # 一次重启
chk "IP反复变化-3 applied_ip更新为最终IP" "10.0.0.3" "$applied_ip"
chk "IP反复变化-3 state=最终IP" "10.0.0.3" "$(cat "$MONITOR_IP_STATE_FILE")"
chk "IP反复变化: 全程只进行一次重启" 1 "$(count 's6-rc -u change dnf-channel')"
chk "IP反复变化: d dnf-channel 执行3次(2次等待+1次成功)" 3 "$(count 's6-rc -d change dnf-channel')"

# 重启过程中某个服务启动失败: applied_ip 不更新，下次重试
setup "1.2.3.4" "1.2.3.4"
echo "-u change dnf-channel" >"$hardfail_file"
handle_ip_change "9.9.9.9" "test" 1
chk "重启时某服务启动失败失败 handle仍返回0" 0 "$?"
chk "重启时某服务启动失败失败 d dnf-channel 已下线" 1 "$(count 's6-rc -d change dnf-channel')"
chk "重启时某服务启动失败失败 u dnf-channel 已尝试" 1 "$(count 's6-rc -u change dnf-channel')"
chk "重启时某服务启动失败失败 applied_ip 不更新" "1.2.3.4" "$applied_ip"
chk "重启时某服务启动失败失败 state已是最新" "9.9.9.9" "$(cat "$MONITOR_IP_STATE_FILE")"
rm -f "$hardfail_file"
: >"$calls_file"
handle_ip_change "9.9.9.9" "test" 1
chk "重试时 applied_ip 更新为最新" "9.9.9.9" "$applied_ip"
chk "重试后执行一次 u dnf-channel" 1 "$(count 's6-rc -u change dnf-channel')"

setup "" ""
s6rc_try d dnf-channel
chk "s6rc_try 成功返回0" 0 "$?"
setup "" ""
echo 1 >"$fail_file"
s6rc_try d dnf-channel
chk "s6rc_try 获取锁失败返回2" 2 "$?"
setup "" ""
touch "$othererr_file"
s6rc_try d dnf-channel
chk "s6rc_try 其他错误返回1" 1 "$?"

setup "" ""
echo 2 >"$fail_file"
s6rc_change u dnf-channel
chk "s6rc_change 重试后成功返回0" 0 "$?"
chk "s6rc_change 共调用3次" 3 "$(count 's6-rc -u change dnf-channel')"

setup "" ""
touch "$othererr_file"
s6rc_change u dnf-channel
chk "s6rc_change 出现其他错误返回1" 1 "$?"
chk "s6rc_change 出现其他错误时只调用一次" 1 "$(count 's6-rc -u change dnf-channel')"

setup "" ""
echo 99 >"$fail_file"
S6RC_LOCK_RETRY=3
s6rc_change u dnf-channel
rc=$?
S6RC_LOCK_RETRY=10
chk "s6rc_change 到达上限时返回1" 1 "$rc"
chk "s6rc_change 到达上限时共执行3次" 3 "$(count 's6-rc -u change dnf-channel')"

setup "" ""
set_running df_channel_r other_proc
proc_running df_channel_r
chk "proc_running 匹配成功" 0 "$?"
proc_running df_game_r
chk "proc_running 匹配失败" 1 "$?"
proc_running df_chan
chk "proc_running 不匹配子字符串" 1 "$?"

setup "" ""
echo "5.5.5.5" >"$MONITOR_IP_STATE_FILE"
set_running df_game_r
recover_applied_ip
chk "IP变化重启时恢复 applied_ip" "5.5.5.5" "$applied_ip"

setup "" ""
echo "6.6.6.6" >"$MONITOR_IP_STATE_FILE"
set_running unrelated_proc
recover_applied_ip
chk "初次启动时不恢复 applied_ip" "" "$applied_ip"

# monitor重启过程中IP发生变化
setup "" ""
echo "1.1.1.1" >"$MONITOR_IP_STATE_FILE"
set_running df_channel_r
recover_applied_ip
set_running
chk "恢复后 applied_ip=旧IP" "1.1.1.1" "$applied_ip"
handle_ip_change "9.9.9.9" "domain" 1
chk "恢复后IP变化触发重启，applied_ip 更新为最新IP" "9.9.9.9" "$applied_ip"
chk "恢复后IP变化触发重启，执行 u dnf-channel" 1 "$(count 's6-rc -u change dnf-channel')"

setup "" ""
echo "1.1.1.1" >"$MONITOR_IP_STATE_FILE"
set_running df_channel_r
recover_applied_ip
set_running
handle_ip_change "1.1.1.1" "domain" 1
chk "恢复后IP未变化时不重启" 0 "$(count 's6-rc')"
chk "恢复后IP未变化时applied_ip不变" "1.1.1.1" "$applied_ip"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
