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
# 将结果文件拷贝到对应目录[这里是为了保住日志文件目录,将日志文件挂载到宿主机外,因此采用覆盖而不是mv]
cp -rf /home/template/neople-tmp/* /home/neople
rm -rf /home/template/neople-tmp
# 复制版本文件
cp /data/Script.pvf /home/neople/game/Script.pvf
chmod 777 /home/neople/game/Script.pvf
cp /data/df_game_r /home/neople/game/df_game_r
chmod 777 /home/neople/game/df_game_r
cp /data/publickey.pem /home/neople/game/

mv /home/template/root-tmp /root
# 拷贝证书key
cp /data/privatekey.pem /root/
# 构建配置文件软链[不能使用硬链接, 硬链接不可跨设备]
ln -s /data/Config.ini /root/Config.ini
# 替换Config.ini中的GM用户名、密码、连接KEY、登录器版本[这里操作的对象是一个软链接不需要指定-type]
sed -i --follow-symlinks "s/GM_ACCOUNT/$GM_ACCOUNT/g" `find /root -name "*.ini"`
sed -i --follow-symlinks "s/GM_PASSWORD/$GM_PASSWORD/g" `find /root -name "*.ini"`
sed -i --follow-symlinks "s/GM_CONNECT_KEY/$GM_CONNECT_KEY/g" `find /root -name "*.ini"`
sed -i --follow-symlinks "s/GM_LANDER_VERSION/$GM_LANDER_VERSION/g" `find /root -name "*.ini"`

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
