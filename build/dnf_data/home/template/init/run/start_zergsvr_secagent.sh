#!/bin/bash

killall -9 secagent
rm -rf secagent.pid

LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so ./secagent
