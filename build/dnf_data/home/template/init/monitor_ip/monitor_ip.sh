#!/bin/bash

source "${DNF_LIB_PATH:-/home/template/init/lib}/common.sh"

state_file="${MONITOR_IP_STATE_FILE:-/data/monitor_ip/MONITOR_PUBLIC_IP}"

# 当前正在使用的IP，当此IP与解析结果不一致才需要重启
# 用来避免IP频繁变化导致反复重启或由于重启阻塞，使用旧IP重启的情况
applied_ip=""

# 非阻塞式调用 s6-rc
# 返回 0=成功 2=获取锁失败 1=其他错误
s6rc_try() {
    local op="$1" target="$2" err
    if err=$(s6-rc -"$op" change "$target" 2>&1); then
        return 0
    fi
    case "$err" in
    *"unable to take locks"* | *"Resource busy"*) return 2 ;;
    *)
        echo "ERROR: s6-rc -$op change $target failed: $err" >&2
        return 1
        ;;
    esac
}

# 阻塞式调用 s6-rc
# 获取锁失败会一直重试, 若出现其它错误则立即返回
# 用法: s6rc_change d|u TARGET
s6rc_change() {
    local op="$1" target="$2" i=0 max="${S6RC_LOCK_RETRY:-600}" err
    while :; do
        if err=$(s6-rc -"$op" change "$target" 2>&1); then
            return 0
        fi
        case "$err" in
        *"unable to take locks"* | *"Resource busy"*)
            i=$((i + 1))
            if [ "$i" -ge "$max" ]; then
                echo "WARN: s6-rc -$op change $target still lock-busy after ${max} retries, giving up" >&2
                return 1
            fi
            sleep 1
            ;;
        *)
            echo "ERROR: s6-rc -$op change $target failed: $err" >&2
            return 1
            ;;
        esac
    done
}

# 返回 0=已重启 2=获取锁失败 1=其他错误
restart_ip_services() {
    local rc
    s6rc_try d dnf-channel
    rc=$?
    [ "$rc" -ne 0 ] && return "$rc"
    if [ -n "$MAIN_BRIDGE_IP" ]; then
        s6rc_change d dnf-bridge || return 1
        s6rc_change u dnf-bridge || return 1
    fi
    s6rc_change u dnf-channel || return 1
    s6rc_change d llnut_gate || return 1
    s6rc_change u llnut_gate || return 1
    return 0
}

# 处理IP解析结果, 更新 applied_ip
# 参数: NEW_IP SOURCE_DESC INTERVAL
# 返回: 0=IP有效, 1=IP为空
handle_ip_change() {
    local new_ip="$1" source_desc="$2" interval="$3" rc
    if [ -z "$new_ip" ]; then
        echo "${source_desc} ip is empty, wait ${interval} second"
        return 1
    fi
    if [ "$new_ip" != "$(cat "$state_file" 2>/dev/null)" ]; then
        echo "$new_ip" >"$state_file"
    fi
    if [ -z "$applied_ip" ]; then
        echo "${source_desc} ip resolved, ip is ${new_ip}"
        applied_ip="$new_ip"
        return 0
    fi
    if [ "$new_ip" = "$applied_ip" ]; then
        echo "${source_desc} ip not change, ip is ${new_ip}, wait ${interval} second"
        return 0
    fi
    echo "${source_desc} ip changed, applied ip is ${applied_ip}, new ip is ${new_ip}"
    restart_ip_services
    rc=$?
    if [ "$rc" -eq 0 ]; then
        applied_ip="$new_ip"
    elif [ "$rc" -eq 2 ]; then
        echo "${source_desc} s6-rc lock busy, defer restart, retry with latest ip next round" >&2
    else
        echo "WARN: restart for ip ${new_ip} failed" >&2
    fi
    return 0
}

proc_running() {
    pgrep -x "$1" >/dev/null 2>&1
}

recover_applied_ip() {
    if proc_running df_channel_r || proc_running df_game_r || proc_running dnf-gate-server; then
        applied_ip=$(cat "$state_file" 2>/dev/null || true)
    fi
}

# 被 source 时只加载函数
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

recover_applied_ip
rm -rf "$state_file"
MONITOR_PUBLIC_IP=$PUBLIC_IP
# 云服务器自动获取公网IP
while [ -z "$MONITOR_PUBLIC_IP" ] && [ "$AUTO_PUBLIC_IP" = true ]; do
    echo "try to get public ip from get_public_ip.sh"
    # 检查是否成功拿到IP
    auto_ip=$(/data/monitor_ip/get_public_ip.sh 2>/dev/null || true)
    # 连接成功
    if [ -n "$auto_ip" ]; then
        echo "auto get public ip is $auto_ip"
        MONITOR_PUBLIC_IP=$auto_ip
        # 通知其他进程[写入文件]
        echo "$MONITOR_PUBLIC_IP" >"$state_file"
        break
    else
        echo "auto get ip failed, retry"
        # 等待5秒钟
        sleep 5
    fi
done

# Netbird获取内网IP
while [ -z "$MONITOR_PUBLIC_IP" ] && [ -n "$NB_SETUP_KEY" ] && [ -n "$NB_MANAGEMENT_URL" ]; do
    echo "check private ip from $NB_MANAGEMENT_URL"
    # 检查是否连接成功并拿到内网IP
    nb_status=$(netbird status 2>/dev/null || true)
    netbird_ip=$(echo "$nb_status" | grep 'NetBird IP' | awk -F': ' '{print $2}' | cut -d'/' -f1)
    management_status=$(echo "$nb_status" | grep 'Management' | awk -F': ' '{print $2}')
    signal_status=$(echo "$nb_status" | grep 'Signal' | awk -F': ' '{print $2}')
    # 连接成功
    if [ -n "$netbird_ip" ] && [ "$management_status" = "Connected" ] && [ "$signal_status" = "Connected" ]; then
        echo "connected to netbird with ip $netbird_ip"
        MONITOR_PUBLIC_IP=$netbird_ip
        # 通知其他进程[写入文件]
        echo "$MONITOR_PUBLIC_IP" >"$state_file"
        break
    else
        echo "connect failed, netbird_ip is $netbird_ip, management_status is $management_status, signal_status is $signal_status, retry"
        # 等待5秒钟
        sleep 5
    fi
done

# Tailscale获取内网IP
while [ -z "$MONITOR_PUBLIC_IP" ] && [ -n "$TS_AUTH_KEY" ] && [ -n "$TS_LOGIN_SERVER" ]; do
    echo "check private ip from $TS_LOGIN_SERVER"
    # 检查是否连接成功并拿到内网IP
    ts_status=$(/usr/bin/tailscale --socket=/data/tailscale/tailscaled.sock status --json 2>/dev/null | sed -e 's/.*"Self":{//' -e 's/}.*//' | grep -o '"Online":[^,]*' | head -n1 | grep -q ': true$' && echo true || echo false)
    ts_ip=$(/usr/bin/tailscale --socket=/data/tailscale/tailscaled.sock ip --4)
    # 连接成功
    if [ -n "$ts_ip" ] && [ "$ts_status" = "true" ]; then
        echo "connected to tailscale with ip $ts_ip"
        MONITOR_PUBLIC_IP=$ts_ip
        # 通知其他进程[写入文件]
        echo "$MONITOR_PUBLIC_IP" >"$state_file"
        break
    else
        echo "connect failed, ts_ip is $ts_ip, ts_status is $ts_status, retry"
        # 等待5秒钟
        sleep 5
    fi
done

# DDNS等待时间
wait_time=${DDNS_INTERVAL:-10}
# DDNS-域名
while [ -z "$MONITOR_PUBLIC_IP" ] && [ "$DDNS_ENABLE" = true ] && [ -n "$DDNS_DOMAIN" ]; do
    # 获取域名指向的全部IPv4
    ddns_ips=$(getent ahostsv4 "$DDNS_DOMAIN" 2>/dev/null |
        awk '$1 ~ /^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$/ {print $1}' |
        sort -u)
    # 多A记录域名每次解析结果可能不同
    # 只要旧IP依然在列表中就继续使用，否则取第一个IP
    old_ip=$(cat "$state_file" 2>/dev/null || true)
    if [ -n "$old_ip" ] && printf '%s\n' "$ddns_ips" | grep -qxF "$old_ip"; then
        ddns_ip="$old_ip"
    else
        ddns_ip=$(printf '%s\n' "$ddns_ips" | head -n1)
    fi
    handle_ip_change "$ddns_ip" "domain" "$wait_time"
    sleep "$wait_time"
done

# DDNS-IP
while [ -z "$MONITOR_PUBLIC_IP" ] && [ "$DDNS_ENABLE" = true ]; do
    ddns_ip=$(/data/monitor_ip/get_public_ip.sh 2>/dev/null || true)
    handle_ip_change "$ddns_ip" "net" "$wait_time"
    # 等待
    sleep "$wait_time"
done

if [ -z "$MONITOR_PUBLIC_IP" ]; then
    echo "warning!!! empty PUBLIC_IP, exit..."
    exit 1
else
    # 通知其他进程[写入文件]
    echo "$MONITOR_PUBLIC_IP" >"$state_file"
    echo "success, final ip is $MONITOR_PUBLIC_IP"
fi

exec /command/s6-pause
