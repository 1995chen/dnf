#!/bin/bash

killall -q -9 zergsvr
rm -rf zergsvr.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so \
    ./zergsvr -t30 -i1
