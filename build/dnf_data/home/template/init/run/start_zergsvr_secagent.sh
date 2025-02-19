# /bin/bash

killall -9 secagent
rm -rf secagent.pid
sleep 2
./secagent
