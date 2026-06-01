#!/bin/bash

killall -q -9 df_stun_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_64
exec env LD_PRELOAD=/usr/lib/libjemalloc.so.2 \
    ./df_stun_r test
