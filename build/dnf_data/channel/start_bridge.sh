# /bin/bash

# 启动bridge服务
killall -9 df_bridge_r
rm -rf pid/*.pid
echo "starting bridge..."
LD_PRELOAD=/home/template/init/libhook.so ./df_bridge_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
