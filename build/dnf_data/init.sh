#! /bin/bash

# 解压init_sql
if [ ! -d "/home/template/init/init_sql" ];then
  mkdir -p /home/template/init/init_sql/
  tar -zxvf /home/template/init/init_sql.tgz -C /home/template/init/init_sql/
  echo "init init_sql success"
else
  echo "init_sql have already inited, do nothing!"
fi
# 初始化本地数据库
bash /home/template/init/init_local_db.sh
error_code=$?
if [ ! $error_code -eq 0 ]; then
  echo "init local db failed!!!!!"
  exit -1
fi
# 初始化主数据库
bash /home/template/init/init_main_db.sh
error_code=$?
if [ ! $error_code -eq 0 ]; then
  echo "init main db failed!!!!!"
  exit -1
fi
# 初始化大区数据库
bash /home/template/init/init_server_group_db.sh
error_code=$?
if [ ! $error_code -eq 0 ]; then
  echo "init server group db failed!!!!!"
  exit -1
fi
# 判断Script.pvf文件是否初始化过
if [ ! -f "/data/Script.pvf" ];then
  tar -zxvf /home/template/init/Script.tgz -C /home/template/init/
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
    group_programs="$group_programs,game_$SERVER_GROUP_NAME$num"
    echo "" >> /data/conf.d/channel.conf
    echo "[program:game_$SERVER_GROUP_NAME$num]" >> /data/conf.d/channel.conf
    echo "command=/bin/bash -c \"/data/channel/start_game.sh $num $process_sequence\"" >> /data/conf.d/channel.conf
    echo "directory=/home/neople/game" >> /data/conf.d/channel.conf
    echo "user=root" >> /data/conf.d/channel.conf
    echo "autostart=true" >> /data/conf.d/channel.conf
    echo "autorestart=true" >> /data/conf.d/channel.conf
    echo "stopasgroup=true" >> /data/conf.d/channel.conf
    echo "killasgroup=true" >> /data/conf.d/channel.conf
    echo "stdout_logfile=/data/log/game_$SERVER_GROUP_NAME$num.log" >> /data/conf.d/channel.conf
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
# 判断start_bridge脚本是否初始化
if [ ! -f "/data/channel/start_bridge.sh" ];then
  cp /home/template/init/channel/start_bridge.sh /data/channel/
  echo "init start_bridge.sh success"
else
  echo "start_bridge.sh have already inited, do nothing!"
fi
# 判断start_channel脚本是否初始化
if [ ! -f "/data/channel/start_channel.sh" ];then
  cp /home/template/init/channel/start_channel.sh /data/channel/
  echo "init start_channel.sh success"
else
  echo "start_channel.sh have already inited, do nothing!"
fi
# 判断start_game脚本是否初始化
if [ ! -f "/data/channel/start_game.sh" ];then
  cp /home/template/init/channel/start_game.sh /data/channel/
  echo "init start_game.sh success"
else
  echo "start_game.sh have already inited, do nothing!"
fi
# 判断每日脚本是否初始化
if [ ! -f "/data/daily_job/user_daily_script.sh" ];then
  cp /home/template/init/daily_job/user_daily_script.sh /data/daily_job/
  echo "init user_daily_script.sh success"
else
  echo "user_daily_script.sh have already inited, do nothing!"
fi
