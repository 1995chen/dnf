# /bin/bash

killall -9 df_community_r
rm -rf pid/*.pid
./df_community_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
