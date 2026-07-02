#!/bin/bash

PORT="500$SERVER_GROUP"

# 没有配置INDEX或非P2P服务直接退出
if [ "$SERVER_TYPE" = "P2P" ] || [ "$SERVER_TYPE" = "ALL" ]; then
  # P2P服务必须配置P2P_RELAY_INDEX
  if [ -n "$P2P_RELAY_INDEX" ]; then
    # 每隔600秒执行一次任务
    while true
    do
      # 如果IP没有准备好就跳过
      public_ip=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
      if [ -z "$public_ip" ]; then
        echo "public ip is empty, wait 5 seconds"
        sleep 5
        continue
      fi
      MESSAGE="$public_ip,$P2P_RELAY_INDEX,7${SERVER_GROUP}00"    
      echo "Sending: $MESSAGE to $CORE_PUBLIC_IP:$PORT"
      echo "$MESSAGE" | nc "$CORE_PUBLIC_IP" "$PORT"
      sleep 60
    done
  fi
fi

# 非P2P无需启动
if [[ "$SERVER_TYPE" != "P2P" ]];then
  echo "SERVER_TYPE not P2P, exit"
fi

# P2P服务配置缺失
if [ -z "$P2P_RELAY_INDEX" ];then
  echo "WARNING: P2P_RELAY_INDEX is empty, exit"
fi

sleep 5
