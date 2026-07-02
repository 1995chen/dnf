# /bin/bash

killall -9 df_coserver_r
rm -rf pid/*.pid

# 生成配置文件
rm -rf /tmp/coserver.cfg
rm -rf /home/neople/coserver/cfg/server.cfg
cp /home/template/neople/coserver/cfg/server.cfg /tmp/coserver.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/coserver.cfg
cp /tmp/coserver.cfg /home/neople/coserver/cfg/server.cfg
# 清理cfg文件
rm -rf /tmp/coserver.cfg
echo "starting coserver..."

LD_PRELOAD=/home/template/init/libhook.so ./df_coserver_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
