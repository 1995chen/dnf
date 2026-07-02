# /bin/bash

old_pid=$(pgrep -f "df_dbmw_r server_02 start")
if [ -n "$old_pid" ]; then
  echo "prepare to kill old pid:$old_pid"
  kill -9 $old_pid
else
    echo "no need to kill process"
fi

rm -rf pid/*.pid

# 生成配置文件
rm -rf /tmp/dbmw_guild.cfg
rm -rf /home/neople/dbmw_guild/cfg/server_02.cfg
cp /home/template/neople/dbmw_guild/cfg/server_02.cfg /tmp/dbmw_guild.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/dbmw_guild.cfg
sed -i "s/DEC_GAME_PWD/$DEC_GAME_PWD/g" /tmp/dbmw_guild.cfg
cp /tmp/dbmw_guild.cfg /home/neople/dbmw_guild/cfg/server_02.cfg
# 清理cfg文件
rm -rf /tmp/dbmw_guild.cfg
echo "starting dbmw_guild..."

LD_PRELOAD=/home/template/init/libhook.so ./df_dbmw_r server_02 start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
