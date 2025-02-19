# /bin/bash

killall -9 df_relay_r
rm -rf pid/*.pid
./df_relay_r relay_200 start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
