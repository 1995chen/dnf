# /bin/bash
killall -9 df_channel_r
rm -rf pid/*.pid
# 等待bridge启动,最多等待10秒
counter=0
while [ $counter -lt 10 ]
do
  if nc -zv 127.0.0.1 7000 2>&1 | grep succeeded >/dev/null ; then
    echo "bridge 7000 port ready"
    break
  fi
  sleep 1
  ((counter++))
done
echo "starting channel..."
./df_channel_r channel start
sleep 2
cat pid/*.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
