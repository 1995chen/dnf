#! /bin/bash
host_ip=$(hostname -i | awk '{print $1}')
gateway_ip=$(echo $host_ip | awk -F. '{print $1"."$2"."$3".1"}')
echo "container ip: $host_ip, gateway: $gateway_ip"
# 请在下方添加添加你的ip白名单,例如192.168.6.1:
# mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
#   insert into d_taiwan.geo_allow values ('192.168.6.1', "*", "2016-04-09 23:53:04");
# EOF