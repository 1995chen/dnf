#!/bin/bash

killall -9 secagent
rm -rf secagent.pid

# 等待zergsvr完成初始化。
counter=0
while [ "$counter" -lt 60 ]; do
    if [ -f /home/neople/secsvr/zergsvr/zergsvr.pid ]; then
        echo "zergsvr daemon ready"
        break
    fi
    echo "waiting for zergsvr.pid... $counter"
    sleep 2
    ((counter++))
done

LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so ./secagent
