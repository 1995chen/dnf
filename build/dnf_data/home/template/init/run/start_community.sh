# /bin/bash

killall -9 df_community_r
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
rm -rf /tmp/community.cfg
rm -rf /home/neople/community/cfg/server.cfg
cp /home/template/neople/community/cfg/server.cfg /tmp/community.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/community.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/community.cfg
cp /tmp/community.cfg /home/neople/community/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/community.cfg
echo "starting community..."
# 这里配置文件ip必须为127.0.0.1/0.0.0.0
./df_community_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
