#! /bin/bash

# 定义方法
initMysql(){
  # 清理数据
  rm -rf /var/lib/mysql/*
  # 启动mysql
  mysql_install_db --user=mysql
  service mysql start

  # 导入数据
  mysql -u root <<EOF
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
  service mysql stop
  echo "init mysql success"
}
# 赋予权限
chmod 777 -R /var/lib/mysql
chmod 777 -R /tmp
cd /home/template/init/

# 判断数据库是否初始化过
if [ ! -d "/var/lib/mysql/d_taiwan" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  tar -zxvf /home/template/init/init_sql.tgz
  initMysql
else
  echo "mysql have already inited or use standalone mysql service, do nothing!"
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
# 判断supervisor channel 配置是否初始化
if [ ! -f "/data/conf.d/channel.conf" ];then
  cp /home/template/init/supervisor/channel.conf /data/conf.d/
  echo "init channel.conf success"
else
  echo "channel.conf have already inited, do nothing!"
fi
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
