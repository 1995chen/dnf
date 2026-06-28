#!/bin/bash

# 启动Tailscale
echo "starting tailscale ..."
supervisorctl restart tailscaled
sleep 2
supervisorctl restart tailscale
# 启动Netbird
echo "starting netbird ..."
supervisorctl restart netbird
sleep 2
# 启动monitor_ip
echo "starting monitor_ip ..."
supervisorctl restart monitor_ip:*
# 这里会一直等PUBLIC_IP设置完成
while true; do
  public_ip=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
  if [ -n "$public_ip" ]; then
      echo "PUBLIC_IP: $public_ip"
      break
  fi
  echo "wait PUBLIC_IP..."
  sleep 2
done

# 启动CORE[如果配置了MAIN_BRIDGE_IP则不启动bridge和Gate]只有CORE需要初始化数据库
if [ "$SERVER_TYPE" = "CORE" ] || [ "$SERVER_TYPE" = "ALL" ]; then
  echo "starting mysql_proxy ..."
  supervisorctl restart mysql_proxy:main_mysql_proxy
  supervisorctl restart mysql_proxy:sg_mysql_proxy
  echo "starting core ..."
  supervisorctl restart core:relay_config_server
  supervisorctl restart core:daily_job
  supervisorctl restart core:monitor
  supervisorctl restart core:manager
  if [ -z "$MAIN_BRIDGE_IP" ] || [ "$MAIN_BRIDGE_IP" = "127.0.0.1" ]; then
    echo "starting bridge ..."
    supervisorctl restart core:bridge
    echo "starting tongyi_gate ..."
    supervisorctl restart tongyi_gate
  fi
  supervisorctl restart core:channel
  supervisorctl restart core:dbmw_guild
  supervisorctl restart core:dbmw_mnt
  supervisorctl restart core:dbmw_stat
  supervisorctl restart core:auction
  supervisorctl restart core:point
  supervisorctl restart core:guild
  supervisorctl restart core:statics
  supervisorctl restart core:coserver
  supervisorctl restart core:community
  supervisorctl restart core:gunnersvr
  supervisorctl restart core:zergsvr_secagent
  supervisorctl restart core:zergsvr
fi

# 启动P2P
if [ "$SERVER_TYPE" = "P2P" ] || [ "$SERVER_TYPE" = "ALL" ]; then
  # P2P服务必须配置P2P_RELAY_INDEX
  if [ -n "$P2P_RELAY_INDEX" ]; then
    echo "starting p2p[stun & relay] ..."
    supervisorctl restart p2p:*
  elif
    echo "WARNING: empty P2P_RELAY_INDEX"
  fi
fi

# 启动GAME
if [ "$SERVER_TYPE" = "GAME" ] || [ "$SERVER_TYPE" = "ALL" ]; then
  echo "starting mysql_proxy ..."
  supervisorctl restart mysql_proxy:main_mysql_proxy
  supervisorctl restart mysql_proxy:sg_mysql_proxy
  echo "starting game ..."
  supervisorctl restart game:*
fi

# 退出前sleep 5秒
sleep 5
