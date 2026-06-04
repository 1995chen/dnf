#!/bin/bash
host_ip=$(hostname -i | awk '{print $1}')
gateway_ip=$(echo "$host_ip" | awk -F. '{print $1"."$2"."$3".1"}')
echo "container ip: $host_ip, gateway: $gateway_ip"
# 放开geo ip限制[添加自定义白名单,例如当服务端无法获取100.66.30.59这个IP的国家信息时,允许连接]
MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_MAIN_DB_HOST" -P "$CUR_MAIN_DB_PORT" -u game <<EOF
  update d_taiwan.geo_allow set allow_c_code='CN' where allow_ip='*';
EOF
MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_MAIN_DB_HOST" -P "$CUR_MAIN_DB_PORT" -u game <<EOF
  insert ignore into d_taiwan.geo_allow values ('$host_ip', "*", "2016-04-09 23:53:04");
EOF
MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_MAIN_DB_HOST" -P "$CUR_MAIN_DB_PORT" -u game <<EOF
  insert ignore into d_taiwan.geo_allow values ('$gateway_ip', "*", "2016-04-09 23:53:04");
EOF
# 请在下方添加添加你的ip白名单,例如192.168.6.1:
# MYSQL_PWD=$DNF_DB_GAME_PASSWORD mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game <<EOF
#   insert ignore into d_taiwan.geo_allow values ('192.168.6.1', "*", "2016-04-09 23:53:04");
# EOF
echo "update d_taiwan.geo_allow done, ALLOW ALL COUNTRY."
