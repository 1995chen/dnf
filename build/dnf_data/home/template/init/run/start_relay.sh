#!/bin/bash
killall -9 df_relay_r
rm -rf pid/*.pid
# 等待CORE_PUBLIC_IP的monitor服务启动,最多等待20秒
counter=0
while [ $counter -lt 20 ]
do
  if nc -zv $MAIN_BRIDGE_IP 7000 2>&1 | grep succeeded >/dev/null ; then
    echo "bridge 7000 port ready"
    break
  fi
  sleep 2
  ((counter++))
done
# 等待MONITOR_PUBLIC_IP设置
while [ -z "$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)" ];
do
  echo "wait set MONITOR_PUBLIC_IP, sleep 5s"
  # 等待5秒钟
  sleep 5
done
# 获取IP
MONITOR_PUBLIC_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
# 生成配置文件
rm -rf /tmp/relay.cfg
cp /home/template/neople/relay/cfg/relay.cfg /tmp/relay.cfg
sed -i "s/CORE_PUBLIC_IP/$CORE_PUBLIC_IP/g" /tmp/relay.cfg
# 重设PUBLIC_IP和server group
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/relay.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/relay.cfg
sed -i "s/P2P_RELAY_INDEX/$P2P_RELAY_INDEX/g" /tmp/relay.cfg
cp /tmp/relay.cfg /home/neople/relay/cfg/relay.cfg
# 清理cfg文件
rm -rf /tmp/relay.cfg
# 启动服务
echo "starting relay..."
./df_relay_r relay start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
