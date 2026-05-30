#!/bin/bash

killall -9 df_manager_r
rm -rf pid/*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/home/template/init/libhook.so \
    ./df_manager_r server nofork
