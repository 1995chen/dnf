# /bin/bash
kill -9 $(pgrep -f "df_game_r siroco52 start")
rm -rf pid/siroco52.pid
./df_game_r siroco52 start
sleep 2
cat pid/siroco52.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
