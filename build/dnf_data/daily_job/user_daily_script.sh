#! /bin/bash

# 放开geo ip限制[添加自定义白名单,例如当服务端无法获取100.66.30.59这个IP的国家信息时,允许连接]
# 请在下方insert into语句后添加添加你的ip白名单
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
  update d_taiwan.geo_allow set allow_c_code='CN' where allow_ip='*';
  insert into d_taiwan.geo_allow values ('100.66.30.59', "*", "2016-04-09 23:53:04");
EOF
echo "update d_taiwan.geo_allow done, ALLOW ALL COUNTRY."
