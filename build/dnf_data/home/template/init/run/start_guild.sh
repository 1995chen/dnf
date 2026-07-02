# /bin/bash

killall -9 df_guild_r
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
rm -rf /tmp/guild.cfg
rm -rf /home/neople/guild/cfg/server.cfg
cp /home/template/neople/guild/cfg/server.cfg /tmp/guild.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/guild.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/guild.cfg
cp /tmp/guild.cfg /home/neople/guild/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/guild.cfg
echo "starting guild..."

LD_PRELOAD=/home/template/init/libhook.so ./df_guild_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
