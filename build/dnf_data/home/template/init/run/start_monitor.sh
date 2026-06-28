# /bin/bash

killall -9 df_monitor_r
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
MONITOR_RELAY_CONFIG=$(cat /data/relay/MONITOR_RELAY_CONFIG 2>/dev/null || true)
# 生成配置文件
rm -rf /tmp/monitor.cfg
rm -rf /home/neople/monitor/cfg/server.cfg
cp /home/template/neople/monitor/cfg/server.cfg /tmp/monitor.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/monitor.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/monitor.cfg
# 添加relay配置
echo "" >> /tmp/monitor.cfg
echo $MONITOR_RELAY_CONFIG >> /tmp/monitor.cfg
cp /tmp/monitor.cfg /home/neople/monitor/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/monitor.cfg
echo "starting monitor..."
cat /home/neople/monitor/cfg/server.cfg

LD_PRELOAD=/home/template/init/libhook.so ./df_monitor_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
