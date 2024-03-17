# /bin/bash
kill -9 $(pgrep -f "df_game_r siroco11 start")
rm -rf pid/siroco11.pid
./df_game_r siroco11 start
sleep 2
cat pid/siroco11.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
