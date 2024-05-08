#! /bin/bash

# 一直循环检测IP是否变更, 变更后重新设置配置文件并重启服务
while [ "$DDNS_ENABLE" = true ] &&  [ -n "$DDNS_DOMAIN" ];
do
  nslookup_output=$(nslookup -debug $DDNS_DOMAIN 2>/dev/null || true)
  ddns_ip=$(echo "$nslookup_output" | awk '/^Address: / { print $2 }')
  echo "found ddns_ip is $ddns_ip"
  if [ "$ddns_ip" != "$(cat /data/ddns/DDNS_IP_RECORD 2>/dev/null || true)" ] ; then
    echo "ip changed, new ip is $ddns_ip"
    PUBLIC_IP=$ddns_ip
    # 复制配置文件
    rm -rf /data/ddns/*.cfg
    cp /home/template/neople/channel/cfg/channel.cfg /data/ddns/channel.cfg
    cp /home/template/neople/game/cfg/siroco11.cfg /data/ddns/siroco11.cfg
    cp /home/template/neople/game/cfg/siroco52.cfg /data/ddns/siroco52.cfg
    # 重设PUBLIC_IP
    find /data/ddns -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/PUBLIC_IP/$PUBLIC_IP/g"
    mv /data/ddns/channel.cfg /home/neople/channel/cfg/channel.cfg
    mv /data/ddns/siroco11.cfg /home/neople/game/cfg/siroco11.cfg
    mv /data/ddns/siroco52.cfg /home/neople/game/cfg/siroco52.cfg
    # 重启服务
    supervisorctl restart dnf:channel dnf:game_siroco11 dnf:game_siroco52
    # 保存本次IP记录
    echo "$PUBLIC_IP" > /data/ddns/DDNS_IP_RECORD
  else
    echo "public ip: $ddns_ip is not change"
  fi
  wait_time=${DDNS_INTERVAL:-10}
  echo "wait $wait_time seconds, sleep..."
  sleep $wait_time
done
# 必须等待一定时间后才可以退出
sleep 10
echo "ddns disabled"
