#! /bin/bash

# 试图自动获取CUR_SG_DB_GAME_ALLOW_IP
if [ -z "$CUR_SG_DB_GAME_ALLOW_IP" ];then
  CUR_SG_DB_GAME_ALLOW_IP=$(ip route | awk '/default/ { print $3 }')
  # 尝试连接mysql自动配置ALLOW_IP
  check_result=$(mysql --connect_timeout=2 -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u game 2>&1)
  error_code=$?
  if [ $error_code -ne 0 ]; then
    echo "try to get game allow ip....."
    mysql_error_code=$(echo "$check_result" | awk '{print $2}')
    if [ "$mysql_error_code" == "1045" ]; then
        CUR_SG_DB_GAME_ALLOW_IP=$(echo $check_result | awk -F"'" '{print $4}')
        echo "set CUR_SG_DB_GAME_ALLOW_IP=$CUR_SG_DB_GAME_ALLOW_IP"
    fi
  fi
fi

echo "init server group db $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
# 循环初始化大区数据库
SG_DB_LIST=("d_channel_${SERVER_GROUP_DB}" "d_guild" "taiwan_${SERVER_GROUP_DB}" "taiwan_${SERVER_GROUP_DB}_2nd" "taiwan_${SERVER_GROUP_DB}_log" "taiwan_${SERVER_GROUP_DB}_web" "taiwan_${SERVER_GROUP_DB}_auction_gold" "taiwan_${SERVER_GROUP_DB}_auction_cera" "taiwan_login" "taiwan_prod" "taiwan_game_event" "taiwan_se_event" "taiwan_login_play" "taiwan_billing")

for db_name in "${SG_DB_LIST[@]}"
do
    echo "prepare init $db_name....."
    # 希洛克数据库要特殊处理,因为其他组件会提前初始化这个数据库导致跳过首次初始化
    if [ "$db_name" == "taiwan_siroco" ]; then
      check_result=$(mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD -e "select * from taiwan_siroco.account_cargo limit 1;" 2>&1)
      error_code=$?
      if [ $error_code -ne 0 ]; then
        mysql_error_code=$(echo "$check_result" | awk '{print $2}')
        if [ "$mysql_error_code" == "1146" ]; then
          echo "sg: need re-init taiwan_siroco."
          mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
            CREATE SCHEMA IF NOT EXISTS $db_name DEFAULT CHARACTER SET utf8 ;
            use $db_name;
            source /home/template/init/init_sql/taiwan_cain.sql;
            flush PRIVILEGES;
EOF
          echo "sg: re-init taiwan_siroco done."
          continue
        fi
      fi
    fi
    check_result=$(mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD -e "use $db_name" 2>&1)
    error_code=$?
    if [ $error_code -eq 0 ]; then
      echo "server group db: $db_name already inited."
    else
      mysql_error_code=$(echo "$check_result" | awk '{print $2}')
      if [ "$mysql_error_code" == "1049" ]; then
          if [ "$db_name" == "d_channel_$SERVER_GROUP_DB" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/d_channel.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_$SERVER_GROUP_DB" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_${SERVER_GROUP_DB}_2nd" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain_2nd.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_${SERVER_GROUP_DB}_log" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain_log.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_${SERVER_GROUP_DB}_web" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain_web.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_${SERVER_GROUP_DB}_auction_gold" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain_auction_gold.sql;
              flush PRIVILEGES;
EOF
            continue
          fi
          if [ "$db_name" == "taiwan_${SERVER_GROUP_DB}_auction_cera" ]; then
            mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/taiwan_cain_auction_cera.sql;
              flush PRIVILEGES;
EOF
            continue 
          fi
          mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
              use $db_name;
              source /home/template/init/init_sql/$db_name.sql;
              flush PRIVILEGES;
EOF
      else
          echo "server group db: can not connect to mysql service $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
          echo $check_result
          exit -1
      fi
    fi
done

# game账户连接大区数据库需要配置game账户权限[主数据库和大区数据库可能是独立的需要单独配置]
echo "server group db: flush privileges....."
mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u root -p$CUR_SG_DB_ROOT_PASSWORD <<EOF
delete from mysql.user where user='game' and host='$CUR_SG_DB_GAME_ALLOW_IP';
flush privileges;
grant all privileges on *.* to 'game'@'$CUR_SG_DB_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
EOF
# 测试并查询数据库连接设置
echo "server group db: show db_connect config, server_group is $SERVER_GROUP"
mysql -h $CUR_SG_DB_HOST -P $CUR_SG_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
select gc_type, gc_ip, gc_channel from taiwan_$SERVER_GROUP_DB.game_channel where gc_type=$SERVER_GROUP;
EOF
echo "server_group_db: init server group-$SERVER_GROUP($SERVER_GROUP_DB) done."