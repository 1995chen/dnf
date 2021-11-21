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
CREATE SCHEMA tw DEFAULT CHARACTER SET utf8 ;
use tw;
source /home/template/init/tw.sql;
flush PRIVILEGES;
EOF
  # 禁止匿名用户登录, 修改root密码, 创建game用户并赋予用户权限
  mysql -u root <<EOF
delete from mysql.user where user='';
update mysql.user set password=password("$DNF_DB_ROOT_PASSWORD") where user="root";
grant all privileges on *.* to 'root'@'%';
grant all privileges on *.* to 'game'@'127.0.0.1' identified by 'uu5!^%jg';
flush privileges;
update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306";
select * from d_taiwan.db_connect;
EOF
  service mysql stop
  echo "init mysql success"
}
# 赋予权限
chmod 777 -R /var/lib/mysql
chmod 777 -R /tmp

# 判断数据库是否初始化过
if [ ! -d "/var/lib/mysql/d_taiwan" ];then
  initMysql
else
  echo "mysql have already inited, do nothing!"
fi

# 判断版本文件是否初始化过
if [ ! -f "/data/Script.pvf" ];then
  rm -rf /data/*
  # 拷贝版本文件到持久化目录
  cp /home/template/init/Script.pvf /data/
  cp /home/template/init/df_game_r /data/
  echo "init data success"
else
  echo "pvf data have already inited, do nothing!"
fi
