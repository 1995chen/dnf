#!/bin/bash

if [ -z "$CUR_SG_DB_GAME_ALLOW_IP" ]; then
    check_result=$(mysql --connect_timeout=2 -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game 2>&1)
    error_code=$?
    if [ "$error_code" -ne 0 ]; then
        echo "try to get game allow ip....."
        mysql_error_code=$(echo "$check_result" | grep -oP "ERROR \K[0-9]+" | head -1)
        if [ "$mysql_error_code" == "1045" ]; then
            CUR_SG_DB_GAME_ALLOW_IP=$(echo "$check_result" | awk -F"'" '{print $4}')
            echo "set CUR_SG_DB_GAME_ALLOW_IP=$CUR_SG_DB_GAME_ALLOW_IP"
        fi
    fi
fi

echo "init server group db $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
# 循环初始化大区数据库
SG_DB_LIST=(
    "d_channel_${SERVER_GROUP_DB}"
    "d_guild"
    "taiwan_${SERVER_GROUP_DB}"
    "taiwan_${SERVER_GROUP_DB}_2nd"
    "taiwan_${SERVER_GROUP_DB}_log"
    "taiwan_${SERVER_GROUP_DB}_web"
    "taiwan_${SERVER_GROUP_DB}_auction_gold"
    "taiwan_${SERVER_GROUP_DB}_auction_cera"
    "taiwan_login"
    "taiwan_prod"
    "taiwan_game_event"
    "taiwan_se_event"
    "taiwan_login_play"
    "taiwan_billing"
)

# 数据库名称到SQL初始化文件的映射
declare -A DB_SQL_MAP=(
    ["d_channel_${SERVER_GROUP_DB}"]="d_channel.sql"
    ["taiwan_${SERVER_GROUP_DB}"]="taiwan_cain.sql"
    ["taiwan_${SERVER_GROUP_DB}_2nd"]="taiwan_cain_2nd.sql"
    ["taiwan_${SERVER_GROUP_DB}_log"]="taiwan_cain_log.sql"
    ["taiwan_${SERVER_GROUP_DB}_web"]="taiwan_cain_web.sql"
    ["taiwan_${SERVER_GROUP_DB}_auction_gold"]="taiwan_cain_auction_gold.sql"
    ["taiwan_${SERVER_GROUP_DB}_auction_cera"]="taiwan_cain_auction_cera.sql"
)

for db_name in "${SG_DB_LIST[@]}"; do
    echo "prepare init $db_name....."
    # 希洛克数据库要特殊处理,因为其他组件会提前初始化这个数据库导致跳过首次初始化
    if [ "$db_name" == "taiwan_siroco" ]; then
        check_result=$(MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root -e "select * from taiwan_siroco.account_cargo limit 1;" 2>&1)
        error_code=$?
        if [ "$error_code" -ne 0 ]; then
            mysql_error_code=$(echo "$check_result" | grep -oP "ERROR \K[0-9]+" | head -1)
            if [ "$mysql_error_code" == "1146" ]; then
                echo "sg: need re-init taiwan_siroco."
                MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root <<EOF
            CREATE SCHEMA IF NOT EXISTS $db_name DEFAULT CHARACTER SET utf8;
            use $db_name;
            source /home/template/init/init_sql/taiwan_cain.sql;
            flush PRIVILEGES;
EOF
                echo "sg: re-init taiwan_siroco done."
                continue
            fi
        fi
    fi

    check_result=$(MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root -e "use $db_name" 2>&1)
    error_code=$?
    if [ "$error_code" -eq 0 ]; then
        echo "server group db: $db_name already inited."
    else
        mysql_error_code=$(echo "$check_result" | grep -oP "ERROR \K[0-9]+" | head -1)
        if [ "$mysql_error_code" == "1049" ]; then
            # 从映射表查找SQL文件,未匹配则回退到同名SQL文件
            sql_file="${DB_SQL_MAP[$db_name]:-$db_name.sql}"
            MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root <<EOF
              CREATE SCHEMA $db_name DEFAULT CHARACTER SET utf8;
              use $db_name;
              source /home/template/init/init_sql/$sql_file;
              flush PRIVILEGES;
EOF
        else
            echo "server group db: can not connect to mysql service $CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
            echo "$check_result"
            exit 1
        fi
    fi
done

# game用户连接大区数据库需要配置game用户权限[主数据库和大区数据库可能是独立的需要单独配置]
echo "server group db: flush privileges....."
MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root <<EOF
delete from mysql.user where user='game' and host not in ('127.0.0.1', 'localhost');
flush privileges;
grant all privileges on *.* to 'game'@'127.0.0.1' identified by '$DNF_DB_GAME_PASSWORD';
grant all privileges on *.* to 'game'@'localhost' identified by '$DNF_DB_GAME_PASSWORD';
grant all privileges on *.* to 'game'@'$CUR_SG_DB_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
EOF
# 测试并查询数据库连接设置
echo "server group db: show db_connect config, server_group is $SERVER_GROUP"
MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game <<EOF
select gc_type, gc_ip, gc_channel from taiwan_$SERVER_GROUP_DB.game_channel where gc_type=$SERVER_GROUP;
EOF

# 扩展的数据库用户权限[主数据库和大区数据库可能是独立的需要单独配置]
# 密码与game用户保持一致
EXTENDED_USERS=()
IFS=$',' read -ra EXTENDED_USERS <<<"$DNF_DB_USER_EXTENDED"
for db_user_extended in "${EXTENDED_USERS[@]}"; do
    [ -z "$db_user_extended" ] && continue
    echo "server group db: extended user: ${db_user_extended}, flush privileges....."
    MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root <<EOF
delete from mysql.user where user='$db_user_extended' and host not in ('127.0.0.1', 'localhost');
flush privileges;
grant all privileges on *.* to '$db_user_extended'@'127.0.0.1' identified by '$DNF_DB_GAME_PASSWORD';
grant all privileges on *.* to '$db_user_extended'@'localhost' identified by '$DNF_DB_GAME_PASSWORD';
grant all privileges on *.* to '$db_user_extended'@'$CUR_SG_DB_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
EOF
    # 测试并查询数据库连接设置
    echo "server group db: using extended user $db_user_extended to show db_connect config, server_group is $SERVER_GROUP"
    MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u "$db_user_extended" <<EOF
select gc_type, gc_ip, gc_channel from taiwan_$SERVER_GROUP_DB.game_channel where gc_type=$SERVER_GROUP;
EOF
done
echo "server_group_db: init server group-$SERVER_GROUP($SERVER_GROUP_DB) done."
