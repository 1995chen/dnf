# /bin/bash

# 启动bridge服务
killall -9 df_bridge_r
rm -rf pid/*.pid

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
rm -rf /tmp/bridge.cfg
rm -rf /home/neople/bridge/cfg/server.cfg
cp /home/template/neople/bridge/cfg/server.cfg /tmp/bridge.cfg
sed -i "s/GAME_PASSWORD/$DNF_DB_GAME_PASSWORD/g" /tmp/bridge.cfg
sed -i "s/SERVER_GROUP_DB/$SERVER_GROUP_DB/g" /tmp/bridge.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/bridge.cfg
cp /tmp/bridge.cfg /home/neople/bridge/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/bridge.cfg
echo "starting bridge..."
# 使用默认的DP降低CPU占用
LD_PRELOAD=/home/template/init/bridge_hook.so:/home/template/init/libhook.so ./df_bridge_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
exit -1