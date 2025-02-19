#! /bin/bash

# 试图自动获取CUR_MAIN_DB_GAME_ALLOW_IP
if [ -z "$CUR_MAIN_DB_GAME_ALLOW_IP" ];then
  CUR_MAIN_DB_GAME_ALLOW_IP=$(ip route | awk '/default/ { print $3 }')
  # 尝试连接mysql自动配置ALLOW_IP
  check_result=$(mysql --connect_timeout=2 -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game 2>&1)
  error_code=$?
  if [ $error_code -ne 0 ]; then
    echo "try to get game allow ip....."
    mysql_error_code=$(echo "$check_result" | awk '{print $2}')
    if [ "$mysql_error_code" == "1045" ]; then
        CUR_MAIN_DB_GAME_ALLOW_IP=$(echo $check_result | awk -F"'" '{print $4}')
        echo "set CUR_MAIN_DB_GAME_ALLOW_IP=$CUR_MAIN_DB_GAME_ALLOW_IP"
    fi
  fi
fi

echo "init main db $CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT"
# 循环初始化主数据库
MAIN_DB_LIST=("d_taiwan" "d_taiwan_secu" "d_technical_report")

for db_name in "${MAIN_DB_LIST[@]}"
do
    echo "prepare init $db_name....."
    check_result=$(mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u root -p$CUR_MAIN_DB_ROOT_PASSWORD -e "use $db_name" 2>&1)
    error_code=$?
    if [ $error_code -eq 0 ]; then
      echo "main db: $db_name already inited."
    else
      mysql_error_code=$(echo "$check_result" | awk '{print $2}')
      if [ "$mysql_error_code" == "1049" ]; then
          echo "main db: prepare to init remote mysql service dnf data."
          mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u root -p$CUR_MAIN_DB_ROOT_PASSWORD <<EOF
          CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8 ;
          use $db_name;
          source /home/template/init/init_sql/$db_name.sql;
          flush PRIVILEGES;
EOF
      else
          echo "main db: can not connect to mysql service $CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT"
          echo $check_result
          exit -1
      fi
    fi
done
# 主数据库需要初始化d_taiwan.db_connect中的数据库连接配置
# 配置game账户权限
echo "main db: flush privileges....."
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u root -p$CUR_MAIN_DB_ROOT_PASSWORD <<EOF
delete from mysql.user where user='game' and host='$CUR_MAIN_DB_GAME_ALLOW_IP';
flush privileges;
grant all privileges on *.* to 'game'@'$CUR_MAIN_DB_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
EOF
echo "main db: flush privileges done."
# 重置当前大区的主数据库d_taiwan.db_connect表配置
echo "main_db: reset db_connect config, server_group is $SERVER_GROUP"
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u root -p$CUR_MAIN_DB_ROOT_PASSWORD <<EOF
use d_taiwan;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_taiwan", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 1;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_taiwan_secu", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 10;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_technical_report", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 15;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="d_guild", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 8;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_$SERVER_GROUP_DB", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=2;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_2nd", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=3;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_log", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=4;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_web", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=5;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_login", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=6;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_prod", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=7;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_game_event", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=9;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_login_play", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=11;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_auction_gold", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=12;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_se_event", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=13;
update db_connect set db_ip="127.0.0.1", db_port="3306", db_name="taiwan_billing", db_passwd="$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=14;
EOF
# 测试并查询数据库连接设置
echo "main_db: show db_connect config, server_group is $SERVER_GROUP"
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
select db_name, db_ip, db_port, db_passwd from d_taiwan.db_connect where db_server_group=$SERVER_GROUP;
EOF
echo "main_db: init server group-$SERVER_GROUP($SERVER_GROUP_DB) done."
