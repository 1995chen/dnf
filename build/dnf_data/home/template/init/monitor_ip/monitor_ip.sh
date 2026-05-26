#!/bin/bash

source /home/template/init/lib/common.sh

# IP变更后重启服务
# 参数: NEW_IP SOURCE_DESC INTERVAL
# 返回: 0=IP有效, 1=IP为空
handle_ip_change() {
    local new_ip="$1" source_desc="$2" interval="$3"
    local old_ip
    old_ip=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
    # 判断IP是否为空
    if [ -z "$new_ip" ]; then
        echo "${source_desc} ip is empty, wait ${interval} second"
        return 1
    fi
    # 判断IP是否发生变化
    if [ "$new_ip" != "$old_ip" ]; then
        echo "${source_desc} ip changed, old ip is ${old_ip}, new ip is ${new_ip}"
        # 通知其他进程[写入文件]
        echo "$new_ip" >/data/monitor_ip/MONITOR_PUBLIC_IP
        supervisorctl stop dnf_channel:*
        if [ -n "$MAIN_BRIDGE_IP" ]; then
            supervisorctl stop dnf:bridge
        fi
        kill_graceful 3 df_bridge_r df_channel_r
        killall -9 df_game_r 2>/dev/null || true
        sleep 1
        if [ -n "$MAIN_BRIDGE_IP" ]; then
            supervisorctl start dnf:bridge
            wait_for_port "$MAIN_BRIDGE_IP" 7000 30 || true
        fi
        supervisorctl start dnf_channel:*
        supervisorctl restart llnut_gate
    else
        echo "${source_desc} ip not change, ip is ${new_ip}, wait ${interval} second"
    fi
    return 0
}

# 清除MONITOR_PUBLIC_IP文件
rm -rf /data/monitor_ip/MONITOR_PUBLIC_IP
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
        echo "$MONITOR_PUBLIC_IP" >/data/monitor_ip/MONITOR_PUBLIC_IP
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
        echo "$MONITOR_PUBLIC_IP" >/data/monitor_ip/MONITOR_PUBLIC_IP
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
        echo "$MONITOR_PUBLIC_IP" >/data/monitor_ip/MONITOR_PUBLIC_IP
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
    old_ip=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
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
    echo "$MONITOR_PUBLIC_IP" >/data/monitor_ip/MONITOR_PUBLIC_IP
    echo "success, final ip is $MONITOR_PUBLIC_IP"
fi

# 保证启动超过 supervisor startsecs，防止被当作启动失败
sleep 2
