#!/bin/bash

killall -9 gunnersvr
rm -rf ./*.pid
# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so ./gunnersvr -t30 -i1
sleep 2
cat ./*.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
