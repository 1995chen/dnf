# /bin/bash

killall -9 df_monitor_r
rm -rf pid/*.pid
# 替换SERVER_GROUP
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /home/neople/monitor/cfg/server.cfg
LD_PRELOAD=/home/template/init/libhook.so ./df_monitor_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
