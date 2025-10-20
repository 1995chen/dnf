# /bin/bash

# 启动bridge服务
killall -9 df_bridge_r
rm -rf pid/*.pid
echo "starting bridge..."
# 使用默认的DP降低CPU占用
LD_PRELOAD=/home/template/init/bridge_hook.so:/home/template/init/libhook.so ./df_bridge_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
