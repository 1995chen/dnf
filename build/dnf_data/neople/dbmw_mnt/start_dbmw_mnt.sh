# /bin/bash
kill -9 $(pgrep -f "df_dbmw_r server_01 start")
rm -rf pid/*.pid
./df_dbmw_r server_01 start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
