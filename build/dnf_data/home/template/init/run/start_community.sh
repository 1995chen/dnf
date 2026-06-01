#!/bin/bash

killall -q -9 df_community_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2 \
    ./df_community_r server nofork
