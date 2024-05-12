#! /bin/bash

# 云服务器自动获取公网IP
while [ -z "$PUBLIC_IP" ] && [ "$AUTO_PUBLIC_IP" = true ];
do
  echo "try to get public ip from auto_public_ip.sh"
  # 检查是否成功拿到IP
  auto_ip=$(/data/monitor_ip/auto_public_ip.sh 2>/dev/null || true)
  # 连接成功
  if [ -n "$auto_ip" ]; then
    echo "auto get public ip is $auto_ip"
    PUBLIC_IP=$auto_ip
    # 通知其他进程
    export PUBLIC_IP
    break
  else
    echo "auto get ip failed, retry"
    # 等待5秒钟
    sleep 5
  fi
done

# Netbirf获取内网IP
while [ -z "$PUBLIC_IP" ] && [ -n "$NB_SETUP_KEY" ] && [ -n "$NB_MANAGEMENT_URL" ];
do
  echo "check private ip from $NB_MANAGEMENT_URL"
  # 检查是否连接成功并拿到内网IP
  nb_status=$(netbird status 2>/dev/null || true)
  netbird_ip=$(echo "$nb_status" | grep 'NetBird IP' | awk -F': ' '{print $2}' | cut -d'/' -f1)
  management_status=$(echo "$nb_status" | grep 'Management' | awk -F': ' '{print $2}')
  signal_status=$(echo "$nb_status" | grep 'Signal' | awk -F': ' '{print $2}')
  # 连接成功
  if [ -n "$netbird_ip" ] && [ "$management_status" = "Connected" ] && [ "$signal_status" = "Connected" ]; then
    echo "connected to netbird with ip $netbird_ip"
    PUBLIC_IP=$netbird_ip
    # 将内网IP写入文件中
    echo $PUBLIC_IP > /data/monitor_ip/NETBIRD_IP
    # 通知其他进程
    export PUBLIC_IP
    break
  else
    echo "connect failed, netbird_ip is $netbird_ip, management_status is $management_status, signal_status is $signal_status, retry"
    # 等待5秒钟
    sleep 5
  fi
done

# DDNS-域名
while [ "$DDNS_ENABLE" = true ] &&  [ -n "$DDNS_DOMAIN" ];
do
  old_ip=$(cat /data/monitor_ip/DDNS_IP_RECORD 2>/dev/null || true)
  nslookup_output=$(nslookup -debug $DDNS_DOMAIN 2>/dev/null || true)
  ddns_ip=$(echo "$nslookup_output" | awk '/^Address: / { print $2 }')
  if [ "$ddns_ip" != "$old_ip" ] ; then
    echo "ip changed, old ip is $old_ip, new ip is $ddns_ip"
    PUBLIC_IP=$ddns_ip
    # 通知其他进程
    export PUBLIC_IP
    # 重启所有频道服务
    supervisorctl restart dnf_channel:*
    # 保存本次IP记录
    echo "$PUBLIC_IP" > /data/monitor_ip/DDNS_IP_RECORD
  fi
  # 等待
  wait_time=${DDNS_INTERVAL:-10}
  sleep $wait_time
done

# DDNS-IP
while [ "$DDNS_ENABLE" = true ];
do
  old_ip=$(cat /data/monitor_ip/DDNS_IP_RECORD 2>/dev/null || true)
  ddns_ip=$(/data/monitor_ip/get_ddns_ip.sh 2>/dev/null || true)
  if [ "$ddns_ip" != "$old_ip" ] ; then
    echo "ip changed, old ip is $old_ip, new ip is $ddns_ip"
    PUBLIC_IP=$ddns_ip
    # 通知其他进程
    export PUBLIC_IP
    # 重启所有频道服务
    supervisorctl restart dnf_channel:*
    # 保存本次IP记录
    echo "$PUBLIC_IP" > /data/monitor_ip/DDNS_IP_RECORD
  fi
  # 等待
  wait_time=${DDNS_INTERVAL:-10}
  sleep $wait_time
done

# 必须等待一定时间后才可以退出
sleep 10
if [ -z "$PUBLIC_IP" ]; then
  echo "warning!!! empty PUBLIC_IP, exit..."
  exit -1
else
  echo "success, final ip is $PUBLIC_IP"
fi
