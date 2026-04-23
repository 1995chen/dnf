#!/bin/bash

source /home/template/init/lib/common.sh

killall -9 df_channel_r
rm -rf pid/*.pid
# 等待bridge启动,最多等待20秒
wait_for_port "$MAIN_BRIDGE_IP" 7000 20
# 等待MONITOR_PUBLIC_IP设置
if ! MONITOR_PUBLIC_IP=$(wait_for_monitor_ip); then
    echo "ERROR: timeout waiting for MONITOR_PUBLIC_IP, cannot start channel" >&2
    exit 1
fi
# 生成配置文件
rm -rf /tmp/channel.cfg
cp /home/template/neople/channel/cfg/server.cfg /tmp/channel.cfg
safe_sed "MAIN_BRIDGE_IP" "$MAIN_BRIDGE_IP" /tmp/channel.cfg
# 重设PUBLIC_IP和server group
safe_sed "PUBLIC_IP" "$MONITOR_PUBLIC_IP" /tmp/channel.cfg
safe_sed "SERVER_GROUP" "$SERVER_GROUP" /tmp/channel.cfg
cp /tmp/channel.cfg /home/neople/channel/cfg/channel.cfg
# 清理cfg文件
rm -rf /tmp/channel.cfg
# 启动服务
echo "starting channel..."
# 加载DP并启动,该DP可以被自定义[确保DP路径已经被正确映射]
LD_PRELOAD=/home/template/init/channel_hook.so:/dp2/libhook.so ./df_channel_r channel start
sleep 2
cat pid/*.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
