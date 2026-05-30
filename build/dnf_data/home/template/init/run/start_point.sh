#!/bin/bash

killall -9 df_point_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2 \
    ./df_point_r ./cfg/server.cfg run df_point_r
