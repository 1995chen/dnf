#!/bin/bash

killall -9 zergsvr
rm -rf zergsvr.pid
LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so ./zergsvr -t30 -i1
sleep 5
cat zergsvr.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
