# /bin/bash

killall -9 df_stun_r
rm -rf pid/*.pid
./df_stun_r start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
