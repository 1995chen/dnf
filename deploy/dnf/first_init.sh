#! /bin/bash

# 安装mysql client用于导数据
yum update -y
rpm -ivh https://repo.mysql.com//mysql57-community-release-el7-11.noarch.rpm
yum install mysql-community-client.x86_64 -y

# 该脚本是一次性脚本,运行一次后就不需要再次运行

# 设置一些基本参数

# 数据库root密码
DB_ROOT_PWD="88888888"
# mysql IP地址
DB_IP="127.0.0.1"
# mysql 端口
DB_PORT=3000

# 获得用户路径
USER_PATH=$PWD
# 获取当前路径
CURRENT_PATH=$(dirname $0)

# 初始化脚本, 程序首次启动需要进行一些配置

# 解压缩版本文件并拷贝到相应的目录下(因为GitHub最大上传100M,因此压缩该文件)
# 该版本文件是老牛1.6E Final版本, 无修改

cd $CURRENT_PATH/data
tar -zxvf Script.tgz

# 回到脚本所在位置
cd ..
CURRENT_PATH=$PWD
# 启动mysql
docker-compose up -d dnf-mysql
# 等待10秒
sleep 10
cd $CURRENT_PATH/init_sql
tar -zxvf init_sql.tgz

# 导入数据
mysql -u root -p$DB_ROOT_PWD -P7000 -h $DB_IP  <<EOF
CREATE SCHEMA d_channel DEFAULT CHARACTER SET utf8 ;
use d_channel;
source $CURRENT_PATH/init_sql/d_channel.sql;
CREATE SCHEMA d_guild DEFAULT CHARACTER SET utf8 ;
use d_guild;
source $CURRENT_PATH/init_sql/d_guild.sql;
CREATE SCHEMA d_taiwan_secu DEFAULT CHARACTER SET utf8 ;
use d_taiwan_secu;
source $CURRENT_PATH/init_sql/d_taiwan_secu.sql;
CREATE SCHEMA d_taiwan DEFAULT CHARACTER SET utf8 ;
use d_taiwan;
source $CURRENT_PATH/init_sql/d_taiwan.sql;
CREATE SCHEMA d_technical_report DEFAULT CHARACTER SET utf8 ;
use d_technical_report;
source $CURRENT_PATH/init_sql/d_technical_report.sql;
CREATE SCHEMA taiwan_billing DEFAULT CHARACTER SET utf8 ;
use taiwan_billing;
source $CURRENT_PATH/init_sql/taiwan_billing.sql;
CREATE SCHEMA taiwan_cain_2nd DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_2nd;
source $CURRENT_PATH/init_sql/taiwan_cain_2nd.sql;
CREATE SCHEMA taiwan_cain_auction_cera DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_auction_cera;
source $CURRENT_PATH/init_sql/taiwan_cain_auction_cera.sql;
CREATE SCHEMA taiwan_cain_auction_gold DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_auction_gold;
source $CURRENT_PATH/init_sql/taiwan_cain_auction_gold.sql;
CREATE SCHEMA taiwan_cain_log DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_log;
source $CURRENT_PATH/init_sql/taiwan_cain_log.sql;
CREATE SCHEMA taiwan_cain_web DEFAULT CHARACTER SET utf8 ;
use taiwan_cain_web;
source $CURRENT_PATH/init_sql/taiwan_cain_web.sql;
CREATE SCHEMA taiwan_cain DEFAULT CHARACTER SET utf8 ;
use taiwan_cain;
source $CURRENT_PATH/init_sql/taiwan_cain.sql;
CREATE SCHEMA taiwan_game_event DEFAULT CHARACTER SET utf8 ;
use taiwan_game_event;
source $CURRENT_PATH/init_sql/taiwan_game_event.sql;
CREATE SCHEMA taiwan_login_play DEFAULT CHARACTER SET utf8 ;
use taiwan_login_play;
source $CURRENT_PATH/init_sql/taiwan_login_play.sql;
CREATE SCHEMA taiwan_login DEFAULT CHARACTER SET utf8 ;
use taiwan_login;
source $CURRENT_PATH/init_sql/taiwan_login.sql;
CREATE SCHEMA taiwan_main_web DEFAULT CHARACTER SET utf8 ;
use taiwan_main_web;
source $CURRENT_PATH/init_sql/taiwan_main_web.sql;
CREATE SCHEMA taiwan_mng_manager DEFAULT CHARACTER SET utf8 ;
use taiwan_mng_manager;
source $CURRENT_PATH/init_sql/taiwan_mng_manager.sql;
CREATE SCHEMA taiwan_prod DEFAULT CHARACTER SET utf8 ;
use taiwan_prod;
source $CURRENT_PATH/init_sql/taiwan_prod.sql;
CREATE SCHEMA taiwan_pvp DEFAULT CHARACTER SET utf8 ;
use taiwan_pvp;
source $CURRENT_PATH/init_sql/taiwan_pvp.sql;
CREATE SCHEMA taiwan_se_event DEFAULT CHARACTER SET utf8 ;
use taiwan_se_event;
source $CURRENT_PATH/init_sql/taiwan_se_event.sql;
CREATE SCHEMA taiwan_siroco DEFAULT CHARACTER SET utf8 ;
use taiwan_siroco;
source $CURRENT_PATH/init_sql/taiwan_siroco.sql;
CREATE SCHEMA tw DEFAULT CHARACTER SET utf8 ;
use tw;
source $CURRENT_PATH/init_sql/tw.sql;
flush PRIVILEGES;
EOF

# 回到脚本所在位置
cd $CURRENT_PATH

# 关闭数据库
docker-compose down
# 回到用户所在目录
cd $USER_PATH
# 结束
exit 0
