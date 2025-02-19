# /bin/bash

old_pid=$(pgrep -f "df_dbmw_r server_01 start")
if [ -n "$old_pid" ]; then
  echo "prepare to kill old pid:$old_pid"
  kill -9 $old_pid
else
    echo "no need to kill process"
fi
rm -rf pid/*.pid
LD_PRELOAD=/home/template/init/libhook.so ./df_dbmw_r server_01 start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
