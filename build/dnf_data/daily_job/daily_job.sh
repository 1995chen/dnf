#! /bin/bash

# 每隔1小时执行一次任务
while true
do
  echo "try to run daily job....."
  dt=$(date +'%Y%m')
  echo "create auction_cera and auction_gold table, current date is $dt."
  # 自动创建拍卖行以及金币寄售表
  mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
    CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer_201603;
    CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer_201603;
EOF
  echo "create auction_cera and auction_gold table done."
  # 放开geo ip限制[添加自定义白名单,例如当服务端无法获取100.66.30.59这个IP的国家信息时,允许连接]
    mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
    update d_taiwan.geo_allow set allow_c_code='CN' where allow_ip='*';
    insert into d_taiwan.geo_allow values ('100.66.30.59', "*", "2016-04-09 23:53:04");
EOF
  echo "update d_taiwan.geo_allow done, ALLOW ALL COUNTRY."
  sleep 3600
done
# 等待5秒后退出
sleep 5
