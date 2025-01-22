#! /bin/bash

# 每隔1小时执行一次任务
while true
do
  echo "try to run daily job....."
  dt = $(date +'%Y%m')
  echo "create auction_cera and auction_gold table, current date is $dt."
  # 自动创建拍卖行以及金币寄售表
  if [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
    mysql -h 127.0.0.1 -P 3306 -u game -p$DNF_DB_GAME_PASSWORD <<EOF
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_cera.auction_history_$dt LIKE taiwan_cain_auction_cera.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_cera.auction_history_buyer_$dt LIKE taiwan_cain_auction_cera.auction_history_buyer_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_gold.auction_history_$dt LIKE taiwan_cain_auction_gold.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_gold.auction_history_buyer_$dt LIKE taiwan_cain_auction_gold.auction_history_buyer_201603;
EOF
  else
    mysql -h $MYSQL_HOST -P $MYSQL_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_cera.auction_history_$dt LIKE taiwan_cain_auction_cera.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_cera.auction_history_buyer_$dt LIKE taiwan_cain_auction_cera.auction_history_buyer_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_gold.auction_history_$dt LIKE taiwan_cain_auction_gold.auction_history_201603;
    CREATE TABLE IF NOT EXISTS taiwan_cain_auction_gold.auction_history_buyer_$dt LIKE taiwan_cain_auction_gold.auction_history_buyer_201603;
EOF 
  fi
  echo "create auction_cera and auction_gold table done."
  sleep 3600
done
# 等待5秒后退出
sleep 5
