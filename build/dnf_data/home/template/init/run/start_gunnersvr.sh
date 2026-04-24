#!/bin/bash

killall -9 gunnersvr
rm -rf ./*.pid
LD_PRELOAD=/usr/lib/libglibc_compat.so ./gunnersvr -t30 -i1
sleep 2
cat ./*.pid | xargs -n1 -I{} tail --pid={} -f /dev/null
