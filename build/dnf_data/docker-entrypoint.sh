# 清理日志
rm -rf /home/neople/game/log/siroco11/*
rm -rf /home/neople/game/log/siroco52/*
# 重设supervisor web网页密码
sed -i "s/^username=.*/username=$WEB_USER/" /etc/supervisord.conf
sed -i "s/^password=.*/password=$WEB_PASS/" /etc/supervisord.conf
# 给supervisor扩展文件赋予权限[可用于扩展第三方网关]
mkdir -p /data/conf.d
# 创建DP目录
mkdir -p /data/dp
if [ $(find /data/conf.d -name "*.conf" | wc -l) -gt 0 ]; then
  echo "Add permissions to the extension configuration."
  chmod 777 /data/conf.d/*.conf
else
  echo "Extension configuration not set up."
fi
# 初始化数据
bash /home/template/init/init.sh
# 删除无用文件
rm -rf /home/template/neople-tmp
rm -rf /home/template/root-tmp
mkdir -p /home/neople
# 清理root下文件
rm -rf /root/DnfGateServer
rm -rf /root/GateRestart
rm -rf /root/GateStop
rm -rf /root/run
rm -rf /root/stop
rm -rf /root/Config.ini
rm -rf /root/privatekey.pem

# 复制待使用文件
cp -r /home/template/neople /home/template/neople-tmp
cp -r /home/template/root /home/template/root-tmp

# 自动获取公网ip
if [ -z "$PUBLIC_IP" ] && $AUTO_PUBLIC_IP;
then
  # 等待60秒,如果无法成功获得ip直接退出
  counter=0
  while [ $counter -lt 60 ]
  do
    echo "try to get public ip from 3rd party api"
    # 检查是否成功拿到ddns ip
    auto_ip=$(curl -s https://v4.ident.me 2>/dev/null || true)
    # 连接成功
    if [ -n "$auto_ip" ]; then
      echo "auto get public ip is $auto_ip"
      PUBLIC_IP=$auto_ip
      break
    else
      echo "auto get ip failed, retry"
    fi
    # 等待1秒钟
    sleep 1
    ((counter++))
  done
  if [ -z "$PUBLIC_IP" ]; then
    echo "failed to get public ip from 3rd party api, exiting."
    exit -1
  fi
  echo "auto get public_ip: $PUBLIC_IP"
fi

# 检查Netbird IP
if [ -z "$PUBLIC_IP" ] && [ -n "$NB_SETUP_KEY" ] && [ -n "$NB_MANAGEMENT_URL" ]; then
  # 重新安装netbird service
  if [ ! -f "/etc/init.d/netbird" ];then
    echo "uninstall old netbird service"
    netbird service uninstall
  echo "install new netbird service"
  netbird service install --config /data/netbird/config.json
  echo "starting netbird service[$NB_MANAGEMENT_URL] use setup_key: $NB_SETUP_KEY"
  netbird service start
  NB_FOREGROUND_MODE=false netbird up
  # 等待60秒,如果无法连接直接退出
  counter=0
  while [ $counter -lt 60 ]
  do
    echo "check private ip from $NB_MANAGEMENT_URL"
    # 检查是否连接成功并拿到内网IP
    nb_status=$(netbird status 2>/dev/null || true)
    netbird_ip=$(echo "$nb_status" | grep 'NetBird IP' | awk -F': ' '{print $2}' | cut -d'/' -f1)
    management_status=$(echo "$nb_status" | grep 'Management' | awk -F': ' '{print $2}')
    signal_status=$(echo "$nb_status" | grep 'Signal' | awk -F': ' '{print $2}')
    # 连接成功
    if [ -n "$netbird_ip" ] && [ "$management_status" = "Connected" ] && [ "$signal_status" = "Connected" ]; then
      echo "connected to netbird with ip $netbird_ip"
      PUBLIC_IP=$netbird_ip
      # 将内网IP写入文件中
      echo $PUBLIC_IP >> /data/netbird/NETBIRD_IP
      break
    else
      echo "connect failed, netbird_ip is $netbird_ip, management_status is $management_status, signal_status is $signal_status, retry"
    fi
    # 等待1秒钟
    sleep 1
    ((counter++))
  done
  if [ -z "$PUBLIC_IP" ]; then
    echo "connect to netbird failed, exiting."
    exit -1
  fi
else
    echo "no need to start netbird"
fi

# 检查DDNS
if [ -z "$PUBLIC_IP" ] && [ -n "$DDNS_ENABLE" ] && [ -n "$DDNS_DOMAIN" ]; then
  # 等待60秒,如果无法成功获得ip直接退出
  counter=0
  while [ $counter -lt 60 ]
  do
    echo "check ddns ip from $DDNS_DOMAIN"
    # 检查是否成功拿到ddns ip
    nslookup_output=$(nslookup -debug $DDNS_DOMAIN 2>/dev/null || true)
    ddns_ip=$(echo "$nslookup_output" | awk '/^Address: / { print $2 }')
    # 连接成功
    if [ -n "$ddns_ip" ]; then
      echo "ddns ip is $ddns_ip"
      PUBLIC_IP=$ddns_ip
      break
    else
      echo "lookup dns failed, retry"
    fi
    # 等待1秒钟
    sleep 1
    ((counter++))
  done
  if [ -z "$PUBLIC_IP" ]; then
    echo "failed to lookup dns, exiting."
    exit -1
  fi
  echo "use ddns, get public_ip: $PUBLIC_IP"
  # 记录当前PUBLIC_IP到文件
  mkdir -p /data/ddns/
  echo "$PUBLIC_IP" >> /data/ddns/DDNS_IP_RECORD
fi

# 如果未设置PUBLIC_IP则退出
if [ -z "$PUBLIC_IP" ]; then
  echo "warning!!! empty PUBLIC_IP, exit..."
  exit -1
fi
echo "final PUBLIC_IP is $PUBLIC_IP"
# 替换配置文件中的PUBLIC_IP
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/PUBLIC_IP/$PUBLIC_IP/g"

# 加密GAME密码并修改配置文件
chmod +x /TeaEncrypt
DNF_DB_GAME_PASSWORD=${DNF_DB_GAME_PASSWORD:0:8}
DEC_GAME_PWD=`/TeaEncrypt $DNF_DB_GAME_PASSWORD`
echo "game password: $DNF_DB_GAME_PASSWORD"
echo "game pwd key: $DEC_GAME_PWD"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/GAME_PASSWORD/$DNF_DB_GAME_PASSWORD/g"
find /home/template/neople-tmp -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/DEC_GAME_PWD/$DEC_GAME_PWD/g"

# 将结果文件拷贝到对应目录[这里是为了保住日志文件目录,将日志文件挂载到宿主机外,因此采用复制而不是mv]
cp -rf /home/template/neople-tmp/* /home/neople
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
mv /home/template/root-tmp/* /root/
rm -rf /home/template/root-tmp
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

# 重建root, game用户,并限制game只能容器内服务访问
service mysql start --skip-grant-tables
mysql -u root <<EOF
delete from mysql.user;
flush privileges;
grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD';
grant all privileges on *.* to 'game'@'127.0.0.1' identified by '$DNF_DB_GAME_PASSWORD';
flush privileges;
select user,host,password from mysql.user;
EOF
# 关闭服务
service mysql stop
service mysql start
# 修改数据库IP和端口 & 刷新game账户权限只允许本地登录
mysql -u root -p$DNF_DB_ROOT_PASSWORD -P 3306 -h 127.0.0.1 <<EOF
update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306", db_passwd="$DEC_GAME_PWD";
select * from d_taiwan.db_connect;
EOF

cd /root
# 启动服务
./run
