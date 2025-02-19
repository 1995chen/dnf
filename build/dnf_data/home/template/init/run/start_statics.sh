# /bin/bash

killall -9 df_statics_r
rm -rf pid/*.pid
LD_PRELOAD=/home/template/init/libhook.so ./df_statics_r server start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
