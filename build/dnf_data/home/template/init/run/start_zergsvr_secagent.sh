#!/bin/bash

killall -9 secagent
rm -rf secagent.pid

counter=0
while [ "$counter" -lt 60 ]; do
    if [ -f /home/neople/secsvr/zergsvr/zergsvr.pid ] &&
        ls /dev/shm/sec_tss_sdk_bus_* >/dev/null 2>&1; then
        echo "zergsvr and game server shared memory ready"
        break
    fi
    echo "waiting for shared memory buses... ($counter)"
    sleep 2
    ((counter++))
done

./secagent
