# 删除无用文件
rm -rf /home/template/neople-tmp
rm -rf /home/template/root-tmp
rm -rf /home/neople
rm -rf /root
# 复制待使用文件
cp -r /home/template/neople /home/template/neople-tmp
cp -r /home/template/root /home/template/root-tmp
# 替换环境变量
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" `find /home/template/neople-tmp -type f -name "*.cfg"`
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" `find /home/template/neople-tmp -type f -name "*.tbl"`
# 替换Config.ini中的数据库地址
sed -i "s/GM_ACCOUNT/$GM_ACCOUNT/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_PASSWORD/$GM_PASSWORD/g" `find /home/template/root-tmp -type f -name "*.ini"`
# 将结果文件拷贝到对应目录
mv /home/template/neople-tmp /home/neople
mv /home/template/root-tmp /root
# 复制版本文件
cp /data/Script.pvf /home/neople/game/Script.pvf
cp /data/df_game_r /home/neople/game/df_game_r
chmod 777 /home/neople/game/Script.pvf
chmod 777 /home/neople/game/df_game_r

service mysql start
# 修改数据库IP和端口 & 刷新game账户权限只允许本地登录
mysql -u root -p$DNF_DB_ROOT_PASSWORD -P 3306 -h 127.0.0.1 <<EOF
UPDATE mysql.user SET Host='127.0.0.1' WHERE User='game';
grant all privileges on *.* to 'game'@'127.0.0.1';
flush privileges;
update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306";
select * from d_taiwan.db_connect;
EOF

# 清理日志
find /home/neople/ -name '*.log' -type f -print -exec rm -f {} \;
find /home/neople/ -name '*.pid' -type f -print -exec rm -f {} \;
find /home/neople/ -name 'core.*' -type f -print -exec rm -f {} \;
cd /home/neople/stun
chmod 777 *
rm -f  /home/neople/stun/pid/*.pid
rm -rf /home/neople/stun/log/*.*
cd /home/neople/monitor
chmod 777 *
rm -f  /home/neople/monitor/pid/*.pid
rm -rf  /home/neople/monitor/log/*.*
cd /home/neople/manager
chmod 777 *
rm -f  /home/neople/manager/pid/*.pid
rm -rf  /home/neople/manager/log/*.*
cd /home/neople/relay
chmod 777 *
rm -f  /home/neople/relay/pid/*.pid
rm -rf  /home/neople/relay/log/*.*
cd /home/neople/bridge
chmod 777 *
rm -f  /home/neople/bridge/pid/*.pid
rm -rf  /home/neople/bridge/log/*.*
cd /home/neople/channel
chmod 777 *
rm -f  /home/neople/channel/pid/*.pid
rm -rf  /home/neople/channel/log/*.*
cd /home/neople/dbmw_guild
chmod 777 *
rm -f  /home/neople/dbmw_guild/pid/*.pid
rm -rf  /home/neople/dbmw_guild/log/*.*
cd /home/neople/dbmw_mnt
chmod 777 *
rm -f  /home/neople/dbmw_mnt/pid/*.pid
rm -rf  /home/neople/dbmw_mnt/log/*.*
cd /home/neople/dbmw_stat
chmod 777 *
rm -f  /home/neople/dbmw_stat/pid/*.pid
rm -rf  /home/neople/dbmw_stat/log/*.*
cd /home/neople/auction
chmod 777 *
rm -f  /home/neople/auction/pid/*.pid
rm -rf  /home/neople/auction/log/*.*
cd /home/neople/point
chmod 777 *
rm -f  /home/neople/point/pid/*.pid
rm -rf  /home/neople/point/log/*.*
cd /home/neople/guild
chmod 777 *
rm -f  /home/neople/guild/pid/*.pid
rm -rf  /home/neople/guild/log/*.*
cd /home/neople/statics
chmod 777 *
rm -f  /home/neople/statics/pid/*.pid
rm -rf  /home/neople/statics/log/*.*
cd /home/neople/coserver
chmod 777 *
rm -f  /home/neople/coserver/pid/*.pid
rm -rf  /home/neople/coserver/log/*.*
cd /home/neople/community
chmod 777 *
rm -f /home/neople/community/pid/*.pid
rm -rf /home/neople/community/log/*.*
cd /home/neople/secsvr/gunnersvr
chmod 777 *
rm -f /home/neople/secsvr/gunnersvr/*.pid
cd /home/neople/secsvr/zergsvr
chmod 777 *
rm -f /home/neople/secsvr/zergsvr/*.pid
cd /home/neople/game
chmod 777 *
rm -rf /home/neople/game/log/*
cd /root
# 启动服务
/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf
