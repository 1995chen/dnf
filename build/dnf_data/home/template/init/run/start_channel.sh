#!/bin/bash

source /home/template/init/lib/common.sh

killall -9 df_channel_r
rm -rf pid/*.pid
MONITOR_PUBLIC_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null)
if [ -z "$MONITOR_PUBLIC_IP" ]; then
    echo "ERROR: MONITOR_PUBLIC_IP empty, cannot start channel" >&2
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
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
# 加载DP并启动，该DP可以被自定义，确保DP路径已经被正确映射
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so:/home/template/init/libdofslim.so:/dp2/libhook.so \
    ./df_channel_r channel run
