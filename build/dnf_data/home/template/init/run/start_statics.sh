#!/bin/bash

killall -9 df_statics_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/home/template/init/libhook.so ./df_statics_r server start
sleep 2
cat pid/*.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
