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
rm -rf /data/channel/channel.cfg
cp /home/template/neople/channel/cfg/server.cfg /data/channel/channel.cfg
sed -i "s/MAIN_BRIDGE_IP/$MAIN_BRIDGE_IP/g" /data/channel/channel.cfg
# 重设PUBLIC_IP和server group
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /data/channel/channel.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /data/channel/channel.cfg
cp /data/channel/channel.cfg /home/neople/channel/cfg/channel.cfg
# 清理cfg文件
rm -rf /data/channel/channel.cfg
# 启动服务
echo "starting channel..."
# 查看是否有dp
RAW_HOOK_HASH=`sha256sum /home/template/init/libhook.so`
HOOK_HASH=`sha256sum /dp2/libhook.so`
LD_PATH="/dp2/libhook.so"
# if test "$RAW_HOOK_HASH" != "$HOOK_HASH"
# then
#   echo "enable dp for channel"
#   LD_PATH="${LD_PATH}:/home/template/init/libhook.so"
# fi

LD_PRELOAD="${LD_PATH}" ./df_channel_r channel start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
