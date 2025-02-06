# /bin/bash

# 获得频道传入参数
channel_no=$1
process_sequence=$2
channel_name="siroco$channel_no"

echo "channel_name is $channel_name"
echo "prepare to start ch.$channel_no, process_sequence is $process_sequence"
# 等待bridge启动,最多等待30秒
counter=0
while [ $counter -lt 30 ]
do
  if nc -zv 127.0.0.1 7000 2>&1 | grep succeeded >/dev/null ; then
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
echo "MONITOR_PUBLIC_IP is $MONITOR_PUBLIC_IP"
# 生成配置文件
rm -rf /data/channel/$channel_name.cfg
cp /home/template/neople/game/cfg/siroco.template /data/channel/$channel_name.cfg
# 重设PUBLIC_IP,game密码,频道编号,端口信息等
sed -i "s/CHANNEL_NO/$channel_no/g" /data/channel/$channel_name.cfg
sed -i "s/PROCESS_SEQUENCE/$process_sequence/g" /data/channel/$channel_name.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /data/channel/$channel_name.cfg
sed -i "s/DEC_GAME_PWD/$DEC_GAME_PWD/g" /data/channel/$channel_name.cfg
cp /data/channel/$channel_name.cfg /home/neople/game/cfg/$channel_name.cfg
echo "generate $channel_name.cfg success"
# 清理cfg文件
rm -rf /data/channel/$channel_name.cfg
# 启动服务
old_pid=$(pgrep -f "df_game_r $channel_name start")
echo "ch.$channel_no old pid is $old_pid"
if [ -n "$old_pid" ]; then
  echo "old pid not empty, kill $old_pid"
  kill -9 $old_pid
fi
rm -rf pid/$channel_name.pid

# 查看是否有dp
RAW_HOOK_HASH=`sha256sum /home/template/init/libhook.so`
HOOK_HASH=`sha256sum /dp2/libhook.so`
LD_PATH="/dp2/libhook.so"
if test "$RAW_HOOK_HASH" != "$HOOK_HASH"
then
  echo "enable dp for channel"
  LD_PATH="${LD_PATH}:/home/template/init/libhook.so"
fi

LD_PRELOAD="${LD_PATH}" ./df_game_r $channel_name start
sleep 2
cat pid/$channel_name.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
