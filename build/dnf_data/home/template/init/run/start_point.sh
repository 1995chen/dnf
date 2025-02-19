# /bin/bash

killall -9 df_point_r
rm -rf pid/*.pid
./df_point_r ./cfg/server.cfg start df_point_r
sleep 5
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
