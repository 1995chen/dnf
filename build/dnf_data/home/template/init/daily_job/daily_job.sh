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
  # 执行用户自定义脚本
  bash /data/daily_job/user_daily_script.sh
  sleep 60
done
# 等待5秒后退出
sleep 5
