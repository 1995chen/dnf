# /bin/bash
kill -9 $(pgrep -f "df_dbmw_r dbmw_gld_siroco start")
rm -rf pid/*.pid
./df_dbmw_r dbmw_gld_siroco start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
