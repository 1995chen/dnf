#! /bin/bash

# 大区对应名称
# 1 : 卡恩, 2 :狄瑞吉, 3 : 希洛克, 4 : 普雷prey, 5 : 凱西亞斯casillas, 6 : 赫爾德hilder , 99 : first server  first , 98 : 開發server
# 其他待探索ruke anton seria
# 大区取决于PVF, PVF不支持则会出现大区灰色
# 目前限制只支持1-6区,其他大区数据库暂时没有内置大区数据库配置
export SERVER_GROUP_NAME_1="cain"
export SERVER_GROUP_NAME_2="diregie"
export SERVER_GROUP_NAME_3="siroco"
export SERVER_GROUP_NAME_4="prey"
export SERVER_GROUP_NAME_5="casillas"
export SERVER_GROUP_NAME_6="hilder"
# 去除环境变量前后的单双引号
export MAIN_BRIDGE_IP=$(echo $MAIN_BRIDGE_IP | sed "s/[\'\"]//g")
export SERVER_GROUP_DB=$(echo $SERVER_GROUP_DB | sed "s/[\'\"]//g")
export SERVER_GROUP=$(echo $SERVER_GROUP | sed "s/[\'\"]//g")
export MAIN_MYSQL_HOST=$(echo $MAIN_MYSQL_HOST | sed "s/[\'\"]//g")
export MAIN_MYSQL_PORT=$(echo $MAIN_MYSQL_PORT | sed "s/[\'\"]//g")
export MAIN_MYSQL_ROOT_PASSWORD=$(echo $MAIN_MYSQL_ROOT_PASSWORD | sed "s/[\'\"]//g")
export MAIN_MYSQL_GAME_ALLOW_IP=$(echo $MAIN_MYSQL_GAME_ALLOW_IP | sed "s/[\'\"]//g")
export MYSQL_HOST=$(echo $MYSQL_HOST | sed "s/[\'\"]//g")
export MYSQL_PORT=$(echo $MYSQL_PORT | sed "s/[\'\"]//g")
export MYSQL_GAME_ALLOW_IP=$(echo $MYSQL_GAME_ALLOW_IP | sed "s/[\'\"]//g")
export AUTO_PUBLIC_IP=$(echo $AUTO_PUBLIC_IP | sed "s/[\'\"]//g")
export PUBLIC_IP=$(echo $PUBLIC_IP | sed "s/[\'\"]//g")
export GM_ACCOUNT=$(echo $GM_ACCOUNT | sed "s/[\'\"]//g")
export GM_PASSWORD=$(echo $GM_PASSWORD | sed "s/[\'\"]//g")
export GM_CONNECT_KEY=$(echo $GM_CONNECT_KEY | sed "s/[\'\"]//g")
export GM_LANDER_VERSION=$(echo $GM_LANDER_VERSION | sed "s/[\'\"]//g")
export DNF_DB_ROOT_PASSWORD=$(echo $DNF_DB_ROOT_PASSWORD | sed "s/[\'\"]//g")
export DNF_DB_GAME_PASSWORD=$(echo $DNF_DB_GAME_PASSWORD | sed "s/[\'\"]//g")
export WEB_USER=$(echo $WEB_USER | sed "s/[\'\"]//g")
export WEB_PASS=$(echo $WEB_PASS | sed "s/[\'\"]//g")
export OPEN_CHANNEL=$(echo $OPEN_CHANNEL | sed "s/[\'\"]//g")
export DDNS_ENABLE=$(echo $DDNS_ENABLE | sed "s/[\'\"]//g")
export DDNS_DOMAIN=$(echo $DDNS_DOMAIN | sed "s/[\'\"]//g")
export DDNS_INTERVAL=$(echo $DDNS_INTERVAL | sed "s/[\'\"]//g")
export NB_SETUP_KEY=$(echo $NB_SETUP_KEY | sed "s/[\'\"]//g")
export NB_MANAGEMENT_URL=$(echo $NB_MANAGEMENT_URL | sed "s/[\'\"]//g")
export CLIENT_POOL_SIZE="$(echo "${CLIENT_POOL_SIZE:-10}" | sed "s/[\'\"]//g")"
# 校验用户选择的大区
SERVER_GROUP_NAME_VAR="SERVER_GROUP_NAME_$SERVER_GROUP"
if [ "$SERVER_GROUP" -ge 1 ] && [ "$SERVER_GROUP" -le 6 ]; then
  export SERVER_GROUP_NAME=${!SERVER_GROUP_NAME_VAR}
  echo "server group is $SERVER_GROUP, server group name is $SERVER_GROUP_NAME"
else
  echo "invalid server group: $SERVER_GROUP"
  exit -1
fi
# 大区使用的数据库[不同大区可以共有数据库]
if [ -z "$SERVER_GROUP_DB" ]; then
  export SERVER_GROUP_DB=$SERVER_GROUP_NAME
fi
# 定义主数据库局部变量
CUR_MAIN_DB_HOST=$MAIN_MYSQL_HOST
CUR_MAIN_DB_PORT=$MAIN_MYSQL_PORT
CUR_MAIN_DB_ROOT_PASSWORD=$MAIN_MYSQL_ROOT_PASSWORD
CUR_MAIN_DB_GAME_ALLOW_IP=$MAIN_MYSQL_GAME_ALLOW_IP

# 本地数据库地址配置
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  CUR_MAIN_DB_HOST=127.0.0.1
  CUR_MAIN_DB_PORT=4000
  CUR_MAIN_DB_ROOT_PASSWORD=$DNF_DB_ROOT_PASSWORD
  CUR_MAIN_DB_GAME_ALLOW_IP=127.0.0.1
fi

# 导出环境变量
export CUR_MAIN_DB_HOST
export CUR_MAIN_DB_PORT
export CUR_MAIN_DB_ROOT_PASSWORD
export CUR_MAIN_DB_GAME_ALLOW_IP
echo "main db: $CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT allow ip $CUR_MAIN_DB_GAME_ALLOW_IP"

# 针对大区数据库定义局部变量
CUR_SG_DB_HOST=$MYSQL_HOST
CUR_SG_DB_PORT=$MYSQL_PORT
CUR_SG_DB_ROOT_PASSWORD=$DNF_DB_ROOT_PASSWORD
CUR_SG_DB_GAME_ALLOW_IP=$MYSQL_GAME_ALLOW_IP

# 本地数据库地址配置
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  CUR_SG_DB_HOST=127.0.0.1
  CUR_SG_DB_PORT=4000
  CUR_SG_DB_GAME_ALLOW_IP=127.0.0.1
fi

# 导出环境变量
export CUR_SG_DB_HOST
export CUR_SG_DB_PORT
export CUR_SG_DB_ROOT_PASSWORD
export CUR_SG_DB_GAME_ALLOW_IP
echo "server group db: $CUR_SG_DB_HOST:$CUR_SG_DB_PORT allow ip $CUR_SG_DB_GAME_ALLOW_IP"
echo "will use server group: $SERVER_GROUP_NAME"
# TODO进行一些强校验,提前退出

# 加密GAME密码
chmod 777 -R /tmp
chmod +x /TeaEncrypt
export DNF_DB_GAME_PASSWORD=${DNF_DB_GAME_PASSWORD:0:8}
export DEC_GAME_PWD=`/TeaEncrypt $DNF_DB_GAME_PASSWORD`
echo "game password: $DNF_DB_GAME_PASSWORD"
echo "game pwd key: $DEC_GAME_PWD"

# 清除mysql sock以及pid文件
rm -rf /var/lib/mysql/mysql.sock
rm -rf /var/lib/mysql/*.pid
rm -rf /var/lib/mysql/*.err
# 清除MONITOR_PUBLIC_IP文件
rm -rf /data/monitor_ip/MONITOR_PUBLIC_IP
# 清理日志
for i in {1..52}; do
    rm -rf /home/neople/game/log/diregie$(printf "%02d" $i)/*
    rm -rf /home/neople/game/log/cain$(printf "%02d" $i)/*
    rm -rf /home/neople/game/log/siroco$(printf "%02d" $i)/*
done
# 启动时清理日志
rm -rf /data/log/*
rm -rf /home/neople/game/log/*
# 清理/dp2目录
rm -rf /dp2
# 给supervisor扩展文件赋予权限[可用于扩展第三方网关]
mkdir -p /data/conf.d
# 创建DP目录
mkdir -p /data/dp
ln -s /data/dp /dp2
# 创建日志目录
mkdir -p /data/log
mkdir -p /data/log/netbird
mkdir -p /data/log/tailscale
# 创建ip监控目录
mkdir -p /data/monitor_ip
# 创建daily_job目录
mkdir -p /data/daily_job
# 创建netbird, tailscale目录
mkdir -p /data/netbird
mkdir -p /data/tailscale
# 创建run脚本目录
mkdir -p /data/run
# 初始化数据
bash /home/template/init/init.sh
error_code=$?
if [ ! $error_code -eq 0 ]; then
  echo "init failed!!!!!"
  exit -1
fi
# 赋予权限
if [ $(find /data/conf.d -name "*.conf" | wc -l) -gt 0 ]; then
  echo "Add permissions to the extension configuration."
  chmod 777 /data/conf.d/*.conf
else
  echo "Extension configuration not set up."
fi
# 删除无用文件
rm -rf /home/template/neople-tmp
mkdir -p /home/neople
# 清理root下文件
rm -rf /root/DnfGateServer
rm -rf /root/GateRestart
rm -rf /root/GateStop
rm -rf /root/Config.ini
rm -rf /root/privatekey.pem

# 复制待使用文件
cp -r /home/template/neople /home/template/neople-tmp
# 修改配置文件
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/GAME_PASSWORD/$DNF_DB_GAME_PASSWORD/g"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/DEC_GAME_PWD/$DEC_GAME_PWD/g"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP_NAME/$SERVER_GROUP_NAME/g"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP_DB/$SERVER_GROUP_DB/g"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP/$SERVER_GROUP/g"
find /home/template/neople-tmp -type f -name "*.tbl" -print0 | xargs -0 sed -i "s/SERVER_GROUP/$SERVER_GROUP/g"

# 将结果文件拷贝到对应目录[这里是为了保住日志文件目录,将日志文件挂载到宿主机外,因此采用复制而不是mv]
cp -rf /home/template/neople-tmp/* /home/neople
# 清理log, pid, core文件
find /home/neople/ -name '*.log' -type f -print -exec rm -f {} \;
find /home/neople/ -name '*.pid' -type f -print -exec rm -f {} \;
find /home/neople/ -name 'core.*' -type f -print -exec rm -f {} \;
chmod 777 -R /home/neople
rm -rf /home/template/neople-tmp
# 复制版本文件
cp /data/Script.pvf /home/neople/game/Script.pvf
chmod 777 /home/neople/game/Script.pvf
# 复制等级文件
cp /data/df_game_r /home/neople/game/df_game_r
chmod 777 /home/neople/game/df_game_r
# 复制通讯私钥文件
cp /data/publickey.pem /home/neople/game/
# 为DP目录赋予权限[为了支持更多未知场景, 这里直接给整个目录777权限]
chmod 777 -R /data/dp
# 重置root目录
cp /home/template/root/* /root/
chmod 777 /root/*
# 拷贝证书key
cp /data/privatekey.pem /root/
# 构建配置文件软链[不能使用硬链接, 硬链接不可跨设备]
ln -s /data/Config.ini /root/Config.ini
# 替换Config.ini中的GM用户名、密码、连接KEY、登录器版本[这里操作的对象是一个软链接不需要指定-type]
sed -i "s/GAME_PASSWORD/$DNF_DB_GAME_PASSWORD/g" `find /data -name "*.ini"`
sed -i "s/GM_ACCOUNT/$GM_ACCOUNT/g" `find /data -name "*.ini"`
sed -i "s/GM_PASSWORD/$GM_PASSWORD/g" `find /data -name "*.ini"`
sed -i "s/GM_CONNECT_KEY/$GM_CONNECT_KEY/g" `find /data -name "*.ini"`
sed -i "s/GM_LANDER_VERSION/$GM_LANDER_VERSION/g" `find /data -name "*.ini"`
# 重设supervisor web网页密码
sed -i "s/^username=.*/username=$WEB_USER/" /etc/supervisord.conf
sed -i "s/^password=.*/password=$WEB_PASS/" /etc/supervisord.conf
# 传递环境变量
SUPERVISORD_ENV="MAIN_BRIDGE_IP=\"$MAIN_BRIDGE_IP\",SERVER_GROUP_NAME=\"$SERVER_GROUP_NAME\",SERVER_GROUP_DB=\"$SERVER_GROUP_DB\",CUR_MAIN_DB_HOST=\"$CUR_MAIN_DB_HOST\",CUR_MAIN_DB_PORT=\"$CUR_MAIN_DB_PORT\",CUR_SG_DB_HOST=\"$CUR_SG_DB_HOST\",CUR_SG_DB_PORT=\"$CUR_SG_DB_PORT\""
sed -i "s/^environment=.*/environment=$SUPERVISORD_ENV/" /etc/supervisord.conf
# 切换到主目录
cd /root
supervisord -c /etc/supervisord.conf
