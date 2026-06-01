#!/bin/bash

# 启动bridge服务
killall -q -9 df_bridge_r
rm -rf pid/*.pid
echo "starting bridge..."
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
# 加载DP和dofslim，降低服务端资源占用
exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so:/home/template/init/libdofslim.so:/home/template/init/libhook.so \
    ./df_bridge_r server run
