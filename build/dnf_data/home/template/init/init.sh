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
run_or_exit "init local db" bash /home/template/init/init_local_db.sh
# 先等主数据库可连接再执行 GRANT
# standalone 部署时防止与 mysql 启动过程的竞态
run_or_exit "wait for main db" bash /home/template/init/wait_for_mysql.sh \
    "$CUR_MAIN_DB_HOST" "$CUR_MAIN_DB_PORT" "$CUR_MAIN_DB_ROOT_PASSWORD"
# 初始化主数据库
run_or_exit "init main db" bash /home/template/init/init_main_db.sh
# 大区数据库部署在不同 host 或端口时同样需要等待
if [ "$CUR_SG_DB_HOST:$CUR_SG_DB_PORT" != "$CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT" ]; then
    run_or_exit "wait for server group db" bash /home/template/init/wait_for_mysql.sh \
        "$CUR_SG_DB_HOST" "$CUR_SG_DB_PORT" "$CUR_SG_DB_ROOT_PASSWORD"
fi
# 初始化大区数据库
run_or_exit "init server group db" bash /home/template/init/init_server_group_db.sh

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

# 判断frida.js文件是否初始化过
if [ ! -f "/data/frida.js" ]; then
    # 拷贝frida.js文件到持久化目录
    cp /home/template/init/frida.js /data/
    echo "init frida.js success"
else
    echo "frida.js have already inited, do nothing!"
fi

# 重新生成channel配置文件[这里要重置下]
rm -rf /etc/supervisor/conf.d/channel.conf
cp /etc/supervisor/conf.d/channel.conf.template /etc/supervisor/conf.d/channel.conf
# 根据环境变量重置频道配置文件
numbers=$(echo "$OPEN_CHANNEL" | awk -F, '{for(i=1;i<=NF;i++){if($i~/-/){split($i,a,"-");for(j=a[1];j<=a[2];j++)printf j" "}else{printf $i" "}}}')
group_programs="channel"

echo "" >>/etc/supervisor/conf.d/channel.conf
# 循环遍历存储的数字
for num in $numbers; do
    if [[ $num -eq 1 || $num -eq 6 || $num -eq 7 || ($num -ge 11 && $num -le 39) || ($num -ge 52 && $num -le 56) ]]; then
        if [ "$num" -ge 11 ] && [ "$num" -le 51 ]; then
            process_sequence=3
        else
            process_sequence=5
        fi
        # 对于小于10的频道补0
        if [[ $num -lt 10 ]]; then
            num="0$num"
        fi
        group_programs="$group_programs,game_${SERVER_GROUP_NAME}${num}"
        cat >>/etc/supervisor/conf.d/channel.conf <<EOF

[program:game_${SERVER_GROUP_NAME}${num}]
command=/bin/bash -c "/data/run/start_game.sh $num $process_sequence"
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_${SERVER_GROUP_NAME}${num}.log
redirect_stderr=true
stdout_logfile_maxbytes=1MB
stderr_logfile_maxbytes=1MB
priority=2000
EOF
        continue
    fi
    echo "invalid channel number: $num"
done
# 添加dnf_channel分组
cat >>/etc/supervisor/conf.d/channel.conf <<EOF

[group:dnf_channel]
programs=$group_programs
priority=999
EOF
echo "init channel.conf success"

# 判断monitor_ip脚本是否初始化[auto_public_ip.sh]
if [ ! -f "/data/monitor_ip/auto_public_ip.sh" ]; then
    cp /home/template/init/monitor_ip/auto_public_ip.sh /data/monitor_ip/
    echo "init auto_public_ip.sh success"
else
    echo "auto_public_ip.sh have already inited, do nothing!"
fi
# 判断monitor_ip脚本是否初始化[get_ddns_ip]
if [ ! -f "/data/monitor_ip/get_ddns_ip.sh" ]; then
    cp /home/template/init/monitor_ip/get_ddns_ip.sh /data/monitor_ip/
    echo "init get_ddns_ip.sh success"
else
    echo "get_ddns_ip.sh have already inited, do nothing!"
fi

# 扫描并更新run脚本
for fp in "/home/template/init/run"/start_*.sh; do
    sh_name=$(basename "$fp")
    target="/data/run/$sh_name"
    [ -f "$target" ] || continue

    reason=""
    # 旧版本启用jemalloc需要先删除全部启动脚本
    if grep -q libjemalloc "$fp" && ! grep -q libjemalloc "$target"; then
        reason="missing jemalloc preload"
    else
        case "$sh_name" in
        start_bridge.sh | start_channel.sh)
            # 旧版本启用DofSlim需要先删除start_bridge.sh和start_channel.sh
            if grep -q libdofslim.so "$fp" && ! grep -q libdofslim.so "$target"; then
                reason="missing libdofslim preload"
            fi
            ;;
        start_game.sh)
            # 旧版本start_game.sh未等待TSS反作弊shm，启动df_game_r后会触发SIGSEGV
            if grep -q "waiting for tss_sdk_bus shm" "$fp" && ! grep -q "waiting for tss_sdk_bus shm" "$target"; then
                reason="missing tss_sdk_bus shm wait"
            fi
            ;;
        start_zergsvr_secagent.sh)
            # 旧版本start_zergsvr_secagent.sh基于shm等待，在未加载libglibc_compat.so的发行版上会死锁
            if grep -q "waiting for zergsvr.pid" "$fp" && ! grep -q "waiting for zergsvr.pid" "$target"; then
                reason="missing zergsvr.pid wait"
            fi
            ;;
        esac
    fi

    if [ -n "$reason" ]; then
        echo "regenerate stale $sh_name: $reason"
        rm -f "$target"
    fi
done

# 初始化所有run脚本
for fp in "/home/template/init/run"/*.sh; do
    if [ -f "$fp" ]; then
        sh_name=$(basename "$fp")
        # 判断脚本是否初始化
        if [ ! -f "/data/run/$sh_name" ]; then
            cp "$fp" "/data/run/"
            echo "init $sh_name success"
        else
            echo "$sh_name have already inited, do nothing!"
        fi
    fi
done

# 判断每日脚本是否初始化
if [ ! -f "/data/daily_job/user_daily_script.sh" ]; then
    cp /home/template/init/daily_job/user_daily_script.sh /data/daily_job/
    echo "init user_daily_script.sh success"
else
    echo "user_daily_script.sh have already inited, do nothing!"
fi
