#!/bin/bash
killall -9 df_channel_r
rm -rf pid/*.pid
# 等待bridge启动,最多等待20秒
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
rm -rf /tmp/channel.cfg
cp /home/template/neople/channel/cfg/server.cfg /tmp/channel.cfg
sed -i "s/MAIN_BRIDGE_IP/$MAIN_BRIDGE_IP/g" /tmp/channel.cfg
# 重设PUBLIC_IP和server group
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/channel.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/channel.cfg
cp /tmp/channel.cfg /home/neople/channel/cfg/channel.cfg
# 清理cfg文件
rm -rf /tmp/channel.cfg
# 启动服务
echo "starting channel..."
# 加载DP并启动,该DP可以被自定义[确保DP路径已经被正确映射]
LD_PRELOAD=/home/template/init/channel_hook.so:/dp2/libhook.so ./df_channel_r channel start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
