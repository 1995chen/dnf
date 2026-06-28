# /bin/bash

killall -9 df_statics_r
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
rm -rf /tmp/statics.cfg
rm -rf /home/neople/statics/cfg/server.cfg
cp /home/template/neople/statics/cfg/server.cfg /tmp/statics.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/statics.cfg
cp /tmp/statics.cfg /home/neople/statics/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/statics.cfg
# 生成tbl文件
rm -rf /tmp/statics_server_config.tbl
rm -rf /home/neople/statics/table/server_config.tbl
cp /home/template/neople/statics/table/server_config.tbl /tmp/statics_server_config.tbl
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/statics_server_config.tbl
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/statics_server_config.tbl
cp /tmp/statics_server_config.tbl /home/neople/statics/table/server_config.tbl
# 清理tbl文件
rm -rf /tmp/statics_server_config.tbl
echo "starting statics..."

LD_PRELOAD=/home/template/init/libhook.so ./df_statics_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
