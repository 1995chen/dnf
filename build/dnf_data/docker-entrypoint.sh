#!/bin/bash

source /home/template/init/lib/common.sh
source /home/template/init/lib/tune.sh

if [ -x /usr/sbin/mysqld ] || [ -x /usr/local/mysql/bin/mysqld ] || [ -x /usr/bin/mysqld ]; then
    tune_resolve_and_export "yes"
else
    tune_resolve_and_export "no"
fi

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
strip_quotes \
    MAIN_BRIDGE_IP SERVER_GROUP_DB SERVER_GROUP \
    MAIN_MYSQL_HOST MAIN_MYSQL_PORT MAIN_MYSQL_ROOT_PASSWORD MAIN_MYSQL_GAME_ALLOW_IP \
    MYSQL_HOST MYSQL_PORT MYSQL_GAME_ALLOW_IP \
    AUTO_PUBLIC_IP PUBLIC_IP \
    GM_ACCOUNT GM_PASSWORD GM_CONNECT_KEY GM_LANDER_VERSION \
    DNF_DB_ROOT_PASSWORD DNF_DB_GAME_PASSWORD \
    WEB_USER WEB_PASS OPEN_CHANNEL \
    DDNS_ENABLE DDNS_DOMAIN DDNS_INTERVAL \
    NB_SETUP_KEY NB_MANAGEMENT_URL \
    DB_USER DB_NAME \
    GATE_AES_KEY GATE_BIND_ADDRESS GATE_RUST_LOG RSA_PRIVATE_KEY_PATH \
    INITIAL_CERA INITIAL_CERA_POINT \
    GATE_TLS_CERT_PATH GATE_TLS_KEY_PATH GATE_TLS_BIND_ADDRESS GATE_TLS_ONLY \
    GAME_SERVER_IP

strip_quotes CLIENT_POOL_SIZE

# 校验用户选择的大区
SERVER_GROUP_NAME_VAR="SERVER_GROUP_NAME_$SERVER_GROUP"
if [ "$SERVER_GROUP" -ge 1 ] && [ "$SERVER_GROUP" -le 6 ]; then
    export SERVER_GROUP_NAME=${!SERVER_GROUP_NAME_VAR}
    echo "server group is $SERVER_GROUP, server group name is $SERVER_GROUP_NAME"
else
    echo "invalid server group: $SERVER_GROUP"
    exit 1
fi
# 大区使用的数据库[不同大区可以共有数据库]
if [ -z "$SERVER_GROUP_DB" ]; then
    export SERVER_GROUP_DB=$SERVER_GROUP_NAME
fi
# 定义主数据库局部变量，优先使用MAIN_MYSQL_*，回退到MYSQL_*
CUR_MAIN_DB_HOST=${MAIN_MYSQL_HOST:-$MYSQL_HOST}
CUR_MAIN_DB_PORT=${MAIN_MYSQL_PORT:-$MYSQL_PORT}
CUR_MAIN_DB_ROOT_PASSWORD=${MAIN_MYSQL_ROOT_PASSWORD:-$DNF_DB_ROOT_PASSWORD}
CUR_MAIN_DB_GAME_ALLOW_IP=${MAIN_MYSQL_GAME_ALLOW_IP:-$MYSQL_GAME_ALLOW_IP}

# 本地数据库地址配置
if [ -z "$CUR_MAIN_DB_HOST" ] && [ -z "$CUR_MAIN_DB_PORT" ]; then
    if [ ! -x /usr/sbin/mysqld ]; then
        echo "ERROR: no local MySQL server and no external MySQL configured."
        echo "Set MYSQL_HOST and MYSQL_PORT (or MAIN_MYSQL_HOST and MAIN_MYSQL_PORT)."
        exit 1
    fi
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

# 定义大区数据库局部变量，优先使用MYSQL_*，回退到MAIN_MYSQL_*
CUR_SG_DB_HOST=${MYSQL_HOST:-$MAIN_MYSQL_HOST}
CUR_SG_DB_PORT=${MYSQL_PORT:-$MAIN_MYSQL_PORT}
CUR_SG_DB_ROOT_PASSWORD=$DNF_DB_ROOT_PASSWORD
CUR_SG_DB_GAME_ALLOW_IP=${MYSQL_GAME_ALLOW_IP:-$MAIN_MYSQL_GAME_ALLOW_IP}

# 本地数据库地址配置
if [ -z "$CUR_SG_DB_HOST" ] && [ -z "$CUR_SG_DB_PORT" ]; then
    if [ ! -x /usr/sbin/mysqld ]; then
        echo "ERROR: no local MySQL server and no external MySQL configured."
        echo "Set MYSQL_HOST and MYSQL_PORT (or MAIN_MYSQL_HOST and MAIN_MYSQL_PORT)."
        exit 1
    fi
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
chmod 1777 /tmp
chmod +x /TeaEncrypt
export DNF_DB_GAME_PASSWORD=${DNF_DB_GAME_PASSWORD:0:8}
DEC_GAME_PWD=$(/TeaEncrypt "$DNF_DB_GAME_PASSWORD")
export DEC_GAME_PWD
echo "game pwd key: ${DEC_GAME_PWD:0:4}..."

# 清风版本需要额外的数据库用户
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF:-supergod,chhappy,cash}"
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF//\'/}"
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF//\"/}"
export DNF_DB_USER_EXTENDED_QF

# 清理残留的运行时文件
rm -f /var/lib/mysql/mysql.sock
rm -f /var/lib/mysql/mysql.sock.lock
rm -f /var/lib/mysql/*.pid
rm -f /var/lib/mysql/*.err
rm -f /var/run/mysqld/mysqld.sock
rm -f /var/run/mysqld/mysqld.sock.lock
rm -f /var/run/mysqld/*.pid
# 清除MONITOR_PUBLIC_IP文件
rm -rf /data/monitor_ip/MONITOR_PUBLIC_IP
# 清理日志
for i in {1..52}; do
    rm -rf "/home/neople/game/log/diregie$(printf "%02d" "$i")"/*
    rm -rf "/home/neople/game/log/cain$(printf "%02d" "$i")"/*
    rm -rf "/home/neople/game/log/siroco$(printf "%02d" "$i")"/*
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
if [ "$error_code" -ne 0 ]; then
    echo "init failed"
    exit 1
fi
# 赋予权限
if [ "$(find /data/conf.d -name "*.conf" | wc -l)" -gt 0 ]; then
    echo "Add permissions to the extension configuration."
    chmod 644 /data/conf.d/*.conf
else
    echo "Extension configuration not set up."
fi
# 删除无用文件
rm -rf /home/template/neople-tmp
mkdir -p /home/neople

# 复制待使用文件
cp -r /home/template/neople /home/template/neople-tmp
# 修改配置文件
while IFS= read -r -d '' cfg_file; do
    safe_sed "GAME_PASSWORD" "$DNF_DB_GAME_PASSWORD" "$cfg_file"
    safe_sed "DEC_GAME_PWD" "$DEC_GAME_PWD" "$cfg_file"
    safe_sed "SERVER_GROUP_NAME" "$SERVER_GROUP_NAME" "$cfg_file"
    safe_sed "SERVER_GROUP_DB" "$SERVER_GROUP_DB" "$cfg_file"
    safe_sed "SERVER_GROUP" "$SERVER_GROUP" "$cfg_file"
done < <(find /home/template/neople-tmp -type f -name "*.cfg" -print0)
while IFS= read -r -d '' tbl_file; do
    safe_sed "SERVER_GROUP" "$SERVER_GROUP" "$tbl_file"
done < <(find /home/template/neople-tmp -type f -name "*.tbl" -print0)

# 将结果文件拷贝到对应目录[这里是为了保住日志文件目录,将日志文件挂载到宿主机外,因此采用复制而不是mv]
cp -rf /home/template/neople-tmp/* /home/neople
# 清理log, pid, core文件
find /home/neople/ -name '*.log' -type f -delete
find /home/neople/ -name '*.pid' -type f -delete
find /home/neople/ -name 'core.*' -type f -delete
chmod 755 -R /home/neople
rm -rf /home/template/neople-tmp
# 复制版本文件
cp /data/Script.pvf /home/neople/game/Script.pvf
chmod 644 /home/neople/game/Script.pvf
# 复制等级文件
cp /data/df_game_r /home/neople/game/df_game_r
chmod 755 /home/neople/game/df_game_r
# 复制通讯私钥文件
cp /data/publickey.pem /home/neople/game/
# 为DP目录赋予权限[为了支持更多未知场景, 这里直接给整个目录777权限]
chmod 777 -R /data/dp
# 重设supervisor web网页密码
sed -i "s/^username=.*/username=$WEB_USER/" /etc/supervisord.conf
sed -i "s/^password=.*/password=$WEB_PASS/" /etc/supervisord.conf
# 传递环境变量
SUPERVISORD_ENV="MAIN_BRIDGE_IP=\"$MAIN_BRIDGE_IP\",SERVER_GROUP_NAME=\"$SERVER_GROUP_NAME\",SERVER_GROUP_DB=\"$SERVER_GROUP_DB\",CUR_MAIN_DB_HOST=\"$CUR_MAIN_DB_HOST\",CUR_MAIN_DB_PORT=\"$CUR_MAIN_DB_PORT\",CUR_SG_DB_HOST=\"$CUR_SG_DB_HOST\",CUR_SG_DB_PORT=\"$CUR_SG_DB_PORT\""
sed -i "s/^environment=.*/environment=$SUPERVISORD_ENV/" /etc/supervisord.conf
# 传递dnf-gate-server环境变量
GATE_ENV="GAME_SERVER_IP=\"${GAME_SERVER_IP:-$PUBLIC_IP}\",DB_HOST=\"$CUR_MAIN_DB_HOST\",DB_PORT=\"$CUR_MAIN_DB_PORT\",DB_USER=\"$DB_USER\",DB_PASSWORD=\"$DNF_DB_GAME_PASSWORD\",DB_NAME=\"$DB_NAME\",AES_KEY=\"$GATE_AES_KEY\",RSA_PRIVATE_KEY_PATH=\"$RSA_PRIVATE_KEY_PATH\",BIND_ADDRESS=\"$GATE_BIND_ADDRESS\",INITIAL_CERA=\"$INITIAL_CERA\",INITIAL_CERA_POINT=\"$INITIAL_CERA_POINT\",TLS_BIND_ADDRESS=\"$GATE_TLS_BIND_ADDRESS\",TLS_ONLY=\"$GATE_TLS_ONLY\",RUST_LOG=\"$GATE_RUST_LOG\""
[ -n "$GATE_TLS_CERT_PATH" ] && GATE_ENV+=",TLS_CERT_PATH=\"$GATE_TLS_CERT_PATH\""
[ -n "$GATE_TLS_KEY_PATH" ] && GATE_ENV+=",TLS_KEY_PATH=\"$GATE_TLS_KEY_PATH\""
# 转义supervisord Python格式字符串中的%，以及sed replacement中的&和\
GATE_ENV="${GATE_ENV//%/%%}"
GATE_ENV=$(printf '%s' "$GATE_ENV" | sed 's/[\\&]/\\&/g')
sed -i "s|^environment=.*|environment=$GATE_ENV|" /etc/supervisor/conf.d/gate.conf
# 切换到主目录
cd /root || exit
supervisord -c /etc/supervisord.conf
