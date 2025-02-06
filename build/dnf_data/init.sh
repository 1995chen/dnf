#! /bin/bash

# 定义方法
initMysql(){
  INIT_MYSQL_IP=127.0.0.1
  INIT_MYSQL_PORT=3306
  # 判断拿到要导入的数据库IP和端口
  if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_PORT" ];then
    INIT_MYSQL_IP=$MYSQL_HOST
    INIT_MYSQL_PORT=$MYSQL_PORT
  fi
  echo "execute init sql to $INIT_MYSQL_IP:$INIT_MYSQL_PORT"
  # 导入数据
  mysql -h $INIT_MYSQL_IP -P $INIT_MYSQL_PORT -u root -p$DNF_DB_ROOT_PASSWORD <<EOF
CREATE SCHEMA d_channel DEFAULT CHARACTER SET utf8 ;
use d_channel;
source /home/template/init/d_channel.sql;
CREATE SCHEMA d_guild DEFAULT CHARACTER SET utf8 ;
use d_guild;
source /home/template/init/d_guild.sql;
CREATE SCHEMA d_taiwan_secu DEFAULT CHARACTER SET utf8 ;
use d_taiwan_secu;
source /home/template/init/d_taiwan_secu.sql;
CREATE SCHEMA d_taiwan DEFAULT CHARACTER SET utf8 ;
use d_taiwan;
source /home/template/init/d_taiwan.sql;
CREATE SCHEMA d_technical_report DEFAULT CHARACTER SET utf8 ;
use d_technical_report;
source /home/template/init/d_technical_report.sql;
CREATE SCHEMA taiwan_billing DEFAULT CHARACTER SET utf8 ;
use taiwan_billing;
source /home/template/init/taiwan_billing.sql;
CREATE SCHEMA taiwan_cain_2nd DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_2nd;
source /home/template/init/taiwan_cain_2nd.sql;
CREATE SCHEMA taiwan_cain_auction_cera DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_auction_cera;
source /home/template/init/taiwan_cain_auction_cera.sql;
CREATE SCHEMA taiwan_cain_auction_gold DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_auction_gold;
source /home/template/init/taiwan_cain_auction_gold.sql;
CREATE SCHEMA taiwan_cain_log DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_log;
source /home/template/init/taiwan_cain_log.sql;
CREATE SCHEMA taiwan_cain_web DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_web;
source /home/template/init/taiwan_cain_web.sql;
CREATE SCHEMA taiwan_cain DEFAULT CHARACTER SET utf8 ;
use taiwan_cain;
source /home/template/init/taiwan_cain.sql;
CREATE SCHEMA taiwan_game_event DEFAULT CHARACTER SET utf8 ;
use taiwan_game_event;
source /home/template/init/taiwan_game_event.sql;
CREATE SCHEMA taiwan_login_play DEFAULT CHARACTER SET utf8 ;
use taiwan_login_play;
source /home/template/init/taiwan_login_play.sql;
CREATE SCHEMA taiwan_login DEFAULT CHARACTER SET utf8 ;
use taiwan_login;
source /home/template/init/taiwan_login.sql;
CREATE SCHEMA taiwan_main_web DEFAULT CHARACTER SET utf8 ;
use taiwan_main_web;
source /home/template/init/taiwan_main_web.sql;
CREATE SCHEMA taiwan_mng_manager DEFAULT CHARACTER SET utf8 ;
use taiwan_mng_manager;
source /home/template/init/taiwan_mng_manager.sql;
CREATE SCHEMA taiwan_prod DEFAULT CHARACTER SET utf8 ;
use taiwan_prod;
source /home/template/init/taiwan_prod.sql;
CREATE SCHEMA taiwan_pvp DEFAULT CHARACTER SET utf8 ;
use taiwan_pvp;
source /home/template/init/taiwan_pvp.sql;
CREATE SCHEMA taiwan_se_event DEFAULT CHARACTER SET utf8 ;
use taiwan_se_event;
source /home/template/init/taiwan_se_event.sql;
CREATE SCHEMA taiwan_siroco DEFAULT CHARACTER SET utf8 ;
use taiwan_siroco;
source /home/template/init/taiwan_siroco.sql;
flush PRIVILEGES;
EOF
  echo "init mysql success"
}
# 赋予权限
chmod 777 -R /tmp
cd /home/template/init/

# 判断数据库是否初始化过
if [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  echo "use local mysql service....."
  if [ ! -d "/var/lib/mysql/d_taiwan" ];then
    echo "prepare to init local mysql data....."
    tar -zxvf /home/template/init/init_sql.tgz
    # 清理数据
    rm -rf /var/lib/mysql/*
    # 启动mysql
    mysql_install_db --user=mysql
    service mysql start
    /usr/bin/mysqladmin -u root password $DNF_DB_ROOT_PASSWORD
    initMysql
    service mysql stop
  else
    echo "local mysql data already inited."
  fi
  echo "local mysql service flush privileges....."
  service mysql start --skip-grant-tables
  mysql -u root <<EOF
  delete from mysql.user;
  flush privileges;
  grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
  grant all privileges on *.* to 'game'@'127.0.0.1' identified by '$DNF_DB_GAME_PASSWORD';
  flush privileges;
  select user,host,password from mysql.user;
  update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306", db_passwd="$DEC_GAME_PWD";
EOF
  # 关闭服务
  service mysql stop
  # 赋予权限
  chmod 777 -R /var/lib/mysql
  service mysql start
  # 测试并查询数据库连接设置
  mysql -h 127.0.0.1 -P 3306 -u game -p$DNF_DB_GAME_PASSWORD <<EOF
    select db_ip, db_port, db_passwd from d_taiwan.db_connect;
EOF
else
  if [ -z "$MYSQL_GAME_ALLOW_IP" ];then
    MYSQL_GAME_ALLOW_IP=$(ip route | awk '/default/ { print $3 }')
    # 尝试连接mysql自动配置ALLOW_IP
    check_result=$(mysql --connect_timeout=2 -h $MYSQL_HOST -P $MYSQL_PORT -u game 2>&1)
    error_code=$?
    if [ $error_code -ne 0 ]; then
      echo "try to get game allow ip....."
      mysql_error_code=$(echo "$check_result" | awk '{print $2}')
      if [ "$mysql_error_code" == "1045" ]; then
          MYSQL_GAME_ALLOW_IP=$(echo $check_result | awk -F"'" '{print $4}')
          echo "set MYSQL_GAME_ALLOW_IP=$MYSQL_GAME_ALLOW_IP"
      fi
    fi
  fi
  echo "use standalone mysql service, MYSQL_GAME_ALLOW_IP is $MYSQL_GAME_ALLOW_IP....."
  check_result=$(mysql -h $MYSQL_HOST -P $MYSQL_PORT -u root -p$DNF_DB_ROOT_PASSWORD -e "use d_taiwan" 2>&1)
  error_code=$?
  if [ $error_code -eq 0 ]; then
    echo "remote mysql data already inited."
  else
    mysql_error_code=$(echo "$check_result" | awk '{print $2}')
    if [ "$mysql_error_code" == "1049" ]; then
        echo "prepare to init remote mysql service dnf data."
        tar -zxvf /home/template/init/init_sql.tgz
        initMysql
    else
        echo "can not connect to remote mysql service $MYSQL_HOST:$MYSQL_PORT"
        echo $check_result
        exit -1
    fi
  fi
  echo "remote mysql service flush privileges....."
  mysql -h $MYSQL_HOST -P $MYSQL_PORT -u root -p$DNF_DB_ROOT_PASSWORD <<EOF
  delete from mysql.user where user='game';
  flush privileges;
  grant all privileges on *.* to 'game'@'$MYSQL_GAME_ALLOW_IP' identified by '$DNF_DB_GAME_PASSWORD';
  select user,host from mysql.user;
  update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306", db_passwd="$DEC_GAME_PWD";
  select * from d_taiwan.db_connect;
  flush privileges;
EOF
  # 测试并查询数据库连接设置
  mysql -h $MYSQL_HOST -P $MYSQL_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
  select db_ip, db_port, db_passwd from d_taiwan.db_connect;
EOF
fi

# 判断Script.pvf文件是否初始化过
if [ ! -f "/data/Script.pvf" ];then
  tar -zxvf /home/template/init/Script.tgz
  # 拷贝版本文件到持久化目录
  cp /home/template/init/Script.pvf /data/
  echo "init Script.pvf success"
else
  echo "Script.pvf have already inited, do nothing!"
fi

# 判断df_game_r文件是否初始化过
if [ ! -f "/data/df_game_r" ];then
  # 拷贝版本文件到持久化目录
  cp /home/template/init/df_game_r /data/
  echo "init df_game_r success"
else
  echo "df_game_r have already inited, do nothing!"
fi

# 判断privatekey.pem文件是否初始化过
if [ ! -f "/data/privatekey.pem" ];then
  # 拷贝版本文件到持久化目录
  cp /home/template/init/privatekey.pem /data/
  echo "init privatekey.pem success"
else
  echo "privatekey.pem have already inited, do nothing!"
fi

# 判断publickey.pem文件是否初始化过
if [ ! -f "/data/publickey.pem" ];then
  # 拷贝版本文件到持久化目录
  cp /home/template/init/publickey.pem /data/
  echo "init publickey.pem success"
else
  echo "publickey.pem have already inited, do nothing!"
fi

# 判断Config.ini文件是否初始化过
if [ ! -f "/data/Config.ini" ];then
  # 拷贝版本文件到持久化目录
  cp /home/template/init/Config.ini /data/
  echo "init Config.ini success"
else
  echo "Config.ini have already inited, do nothing!"
fi
# 判断DP文件是否初始化过
if [ ! -f "/data/dp/libhook.so" ];then
  # 拷贝DP文件到持久化目录
  cp /home/template/init/libhook.so /data/dp/
  echo "init libhook.so success"
else
  echo "libhook.so have already inited, do nothing!"
fi

# 判断supervisor dnf 配置是否初始化
if [ ! -f "/data/conf.d/dnf.conf" ];then
  cp /home/template/init/supervisor/dnf.conf /data/conf.d/
  echo "init dnf.conf success"
else
  echo "dnf.conf have already inited, do nothing!"
fi
# 重新生成channel配置文件
rm -rf /data/conf.d/channel.conf
cp /home/template/init/supervisor/channel.conf /data/conf.d/
# 去除可能存在的单双引号
OPEN_CHANNEL=$(echo $OPEN_CHANNEL | sed "s/[\'\"]//g")
# 根据环境变量重置频道配置文件
numbers=$(echo "$OPEN_CHANNEL" | awk -F, '{for(i=1;i<=NF;i++){if($i~/-/){split($i,a,"-");for(j=a[1];j<=a[2];j++)printf j" "}else{printf $i" "}}}')
process_sequence=3
group_programs="channel"
echo "" >> /data/conf.d/channel.conf
# 循环遍历存储的数字
for num in $numbers; do
  if [[ $num -eq 1 || $num -eq 6 || $num -eq 7 || ($num -ge 11 && $num -le 39) || ($num -ge 52 && $num -le 56) ]];then
    if [ $num -ge 11 ] && [ $num -le 51 ]; then
        process_sequence=3
    else
        process_sequence=5
    fi
    # 对于小于10的频道补0
    if [[ $num -lt 10 ]];then
      num="0$num"
    fi
    group_programs="$group_programs,game_siroco$num"
    echo "" >> /data/conf.d/channel.conf
    echo "[program:game_siroco$num]" >> /data/conf.d/channel.conf
    echo "command=/bin/bash -c \"/data/channel/start_siroco.sh $num $process_sequence\"" >> /data/conf.d/channel.conf
    echo "directory=/home/neople/game" >> /data/conf.d/channel.conf
    echo "user=root" >> /data/conf.d/channel.conf
    echo "autostart=true" >> /data/conf.d/channel.conf
    echo "autorestart=true" >> /data/conf.d/channel.conf
    echo "stopasgroup=true" >> /data/conf.d/channel.conf
    echo "killasgroup=true" >> /data/conf.d/channel.conf
    echo "stdout_logfile=/data/log/game_siroco$num.log" >> /data/conf.d/channel.conf
    echo "redirect_stderr=true" >> /data/conf.d/channel.conf
    echo "depend=channel" >> /data/conf.d/channel.conf
    continue
  fi
  echo "invalid channel number: $num"
done
# 添加dnf_channel分组
echo "" >> /data/conf.d/channel.conf
echo "[group:dnf_channel]" >> /data/conf.d/channel.conf
echo "programs=$group_programs" >> /data/conf.d/channel.conf
echo "priority=999" >> /data/conf.d/channel.conf
echo "init channel.conf success"

# 判断supervisor gate 配置是否初始化
if [ ! -f "/data/conf.d/gate.conf" ];then
  cp /home/template/init/supervisor/gate.conf /data/conf.d/
  echo "init gate.conf success"
else
  echo "gate.conf have already inited, do nothing!"
fi
# 判断monitor_ip脚本是否初始化[auto_public_ip.sh]
if [ ! -f "/data/monitor_ip/auto_public_ip.sh" ];then
  cp /home/template/init/monitor_ip/auto_public_ip.sh /data/monitor_ip/
  echo "init auto_public_ip.sh success"
else
  echo "auto_public_ip.sh have already inited, do nothing!"
fi
# 判断monitor_ip脚本是否初始化[get_ddns_ip]
if [ ! -f "/data/monitor_ip/get_ddns_ip.sh" ];then
  cp /home/template/init/monitor_ip/get_ddns_ip.sh /data/monitor_ip/
  echo "init get_ddns_ip.sh success"
else
  echo "get_ddns_ip.sh have already inited, do nothing!"
fi
# 判断start_channel脚本是否初始化
if [ ! -f "/data/channel/start_channel.sh" ];then
  cp /home/template/init/channel/start_channel.sh /data/channel/
  echo "init start_channel.sh success"
else
  echo "start_channel.sh have already inited, do nothing!"
fi
# 判断start_siroco脚本是否初始化
if [ ! -f "/data/channel/start_siroco.sh" ];then
  cp /home/template/init/channel/start_siroco.sh /data/channel/
  echo "init start_siroco.sh success"
else
  echo "start_siroco.sh have already inited, do nothing!"
fi
# 判断每日脚本是否初始化
if [ ! -f "/data/daily_job/daily_job.sh" ];then
  cp /home/template/init/daily_job/daily_job.sh /data/daily_job/
  echo "init daily_job.sh success"
else
  echo "daily_job.sh have already inited, do nothing!"
fi
