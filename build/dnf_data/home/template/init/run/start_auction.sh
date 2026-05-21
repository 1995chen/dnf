#!/bin/bash

killall -9 df_auction_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
LD_PRELOAD=/usr/lib/libjemalloc32.so.2 ./df_auction_r ./cfg/server.cfg start ./df_auction_r
sleep 5
cat pid/*.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
