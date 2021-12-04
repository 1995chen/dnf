# 删除无用文件
rm -rf /home/template/neople-tmp
rm -rf /home/template/root-tmp
mkdir -p /home/neople
rm -rf /root
# 复制待使用文件
cp -r /home/template/neople /home/template/neople-tmp
cp -r /home/template/root /home/template/root-tmp
# 替换环境变量
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" `find /home/template/neople-tmp -type f -name "*.cfg"`
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" `find /home/template/neople-tmp -type f -name "*.tbl"`
# 替换Config.ini中的GM用户名、密码、连接KEY、登录器版本
sed -i "s/GM_ACCOUNT/$GM_ACCOUNT/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_PASSWORD/$GM_PASSWORD/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_CONNECT_KEY/$GM_CONNECT_KEY/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_LANDER_VERSION/$GM_LANDER_VERSION/g" `find /home/template/root-tmp -type f -name "*.ini"`
# 将结果文件拷贝到对应目录[这里是为了保住日志文件目录,将日志文件挂载到宿主机外,因此采用覆盖而不是mv]
cp -rf /home/template/neople-tmp/* /home/neople
rm -rf /home/template/neople-tmp
mv /home/template/root-tmp /root
# 复制版本文件
cp /data/Script.pvf /home/neople/game/Script.pvf
cp /data/df_game_r /home/neople/game/df_game_r
cp /data/privatekey.pem /root/
cp /data/publickey.pem /home/neople/game/
chmod 777 /home/neople/game/Script.pvf
chmod 777 /home/neople/game/df_game_r

# 重建root, game用户,并限制game只能容器内服务访问
service mysql start --skip-grant-tables
mysql -u root <<EOF
delete from mysql.user;
flush privileges;
grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD';
grant all privileges on *.* to 'game'@'127.0.0.1' identified by 'uu5!^%jg';
flush privileges;
select user,host,password from mysql.user;
EOF
# 关闭服务
service mysql stop
service mysql start
# 修改数据库IP和端口 & 刷新game账户权限只允许本地登录
mysql -u root -p$DNF_DB_ROOT_PASSWORD -P 3306 -h 127.0.0.1 <<EOF
update d_taiwan.db_connect set db_ip="127.0.0.1", db_port="3306";
select * from d_taiwan.db_connect;
EOF

cd /root
# 启动服务
./run
