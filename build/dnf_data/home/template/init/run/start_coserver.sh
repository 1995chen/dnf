# /bin/bash

killall -9 df_coserver_r
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
rm -rf /tmp/coserver.cfg
rm -rf /home/neople/coserver/cfg/server.cfg
cp /home/template/neople/coserver/cfg/server.cfg /tmp/coserver.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/coserver.cfg
cp /tmp/coserver.cfg /home/neople/coserver/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/coserver.cfg
# 生成tbl文件
rm -rf /tmp/coserver_server_config.tbl
rm -rf /home/neople/coserver/table/server_config.tbl
cp /home/template/neople/coserver/table/server_config.tbl /tmp/coserver_server_config.tbl
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/coserver_server_config.tbl
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/coserver_server_config.tbl
cp /tmp/coserver_server_config.tbl /home/neople/coserver/table/server_config.tbl
# 清理tbl文件
rm -rf /tmp/coserver_server_config.tbl
echo "starting coserver..."

LD_PRELOAD=/home/template/init/libhook.so ./df_coserver_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
