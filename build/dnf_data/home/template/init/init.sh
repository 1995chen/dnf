#!/bin/bash

source /home/template/init/lib/common.sh

# 解压init_sql
if [ ! -d "/home/template/init/init_sql" ]; then
    mkdir -p /home/template/init/init_sql/
    tar -zxvf /home/template/init/init_sql.tgz -C /home/template/init/init_sql/
    echo "init init_sql success"
else
    echo "init_sql have already inited, do nothing!"
fi
# 初始化本地数据库
run_or_exit "init local db" bash /home/template/init/init-local-db.sh
# 先等主数据库可连接再执行 GRANT
# standalone 部署时防止与 mysql 启动过程的竞态
run_or_exit "wait for main db" bash /home/template/init/wait-for-mysql.sh \
    "$CUR_MAIN_DB_HOST" "$CUR_MAIN_DB_PORT" "$CUR_MAIN_DB_ROOT_PASSWORD"
# 初始化主数据库
run_or_exit "init main db" bash /home/template/init/init-main-db.sh
# 大区数据库部署在不同 host 或端口时同样需要等待
if [ "$CUR_SG_DB_HOST:$CUR_SG_DB_PORT" != "$CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT" ]; then
    run_or_exit "wait for server group db" bash /home/template/init/wait-for-mysql.sh \
        "$CUR_SG_DB_HOST" "$CUR_SG_DB_PORT" "$CUR_SG_DB_ROOT_PASSWORD"
fi
# 初始化大区数据库
run_or_exit "init server group db" bash /home/template/init/init-server-group-db.sh

# 判断Script.pvf文件是否初始化过
if [ ! -f "/data/Script.pvf" ]; then
    tar -zxvf /home/template/init/Script.tgz -C /home/template/init/
    # 拷贝版本文件到持久化目录
    cp /home/template/init/Script.pvf /data/
    echo "init Script.pvf success"
else
    echo "Script.pvf have already inited, do nothing!"
fi

# 判断df_game_r文件是否初始化过
if [ ! -f "/data/df_game_r" ]; then
    # 拷贝版本文件到持久化目录
    cp /home/template/init/df_game_r /data/
    echo "init df_game_r success"
else
    echo "df_game_r have already inited, do nothing!"
fi

# 判断privatekey.pem文件是否初始化过
if [ ! -f "/data/privatekey.pem" ]; then
    # 首次初始化时生成全新的RSA 2048位密钥对
    openssl genrsa -out /data/privatekey.pem 2048
    openssl rsa -in /data/privatekey.pem -pubout -out /data/publickey.pem
    echo "init privatekey.pem and publickey.pem success (newly generated)"
else
    echo "privatekey.pem have already inited, do nothing!"
    # 若私钥已存在但公钥缺失，从私钥派生公钥
    if [ ! -f "/data/publickey.pem" ]; then
        openssl rsa -in /data/privatekey.pem -pubout -out /data/publickey.pem
        echo "init publickey.pem success (derived from existing privatekey.pem)"
    else
        echo "publickey.pem have already inited, do nothing!"
    fi
fi

# 判断DP文件是否初始化过
if [ ! -f "/data/dp/libhook.so" ]; then
    # 拷贝DP文件到持久化目录
    cp /home/template/init/libhook.so /data/dp/
    echo "init libhook.so success"
else
    echo "libhook.so have already inited, do nothing!"
fi

# 更新时自动备份升级 frida.js
frida_ref_path=/data/.frida-template
mkdir -p "$frida_ref_path"
sync_template_file /home/template/init/frida.js /data/frida.js "$frida_ref_path/frida.js"

# 判断monitor_ip脚本是否初始化[get_public_ip.sh]
if [ ! -f "/data/monitor_ip/get_public_ip.sh" ]; then
    cp /home/template/init/monitor_ip/get_public_ip.sh /data/monitor_ip/
    echo "init get_public_ip.sh success"
else
    echo "get_public_ip.sh have already inited, do nothing!"
fi

# 初始化所有run脚本
ref_path=/data/.run-template
mkdir -p /data/run "$ref_path"
for fp in "/home/template/init/run"/*.sh; do
    [ -f "$fp" ] || continue
    sh_name=$(basename "$fp")
    sync_template_file "$fp" "/data/run/$sh_name" "$ref_path/$sh_name"
done

# 定时任务，src更新时自动升级, 用户改过则保留
scheduler_ref_path=/data/.scheduler-template
mkdir -p /data/scheduler "$scheduler_ref_path"
# 兼容旧路径
if [ -f /data/daily_job/user_daily_script.sh ] && [ ! -e /data/scheduler/user-script.sh ]; then
    cp -f /data/daily_job/user_daily_script.sh /data/scheduler/user-script.sh
    echo "migrate /data/daily_job/user_daily_script.sh -> /data/scheduler/user-script.sh"
fi
if [ -f /data/.daily_job-template/user_daily_script.sh ] && [ ! -e "$scheduler_ref_path/user-script.sh" ]; then
    cp -f /data/.daily_job-template/user_daily_script.sh "$scheduler_ref_path/user-script.sh"
fi
sync_template_file /home/template/init/scheduler/user-script.sh \
    /data/scheduler/user-script.sh \
    "$scheduler_ref_path/user-script.sh"
