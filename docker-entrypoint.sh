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
sed -i "s/DNF_DB_IP/$DNF_DB_IP/g" `find /home/template/neople-tmp -type f -name "*.cfg"`
sed -i "s/DNF_DB_PORT/$DNF_DB_PORT/g" `find /home/template/neople-tmp -type f -name "*.cfg"`

sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" `find /home/template/neople-tmp -type f -name "*.tbl"`
sed -i "s/DNF_DB_IP/$DNF_DB_IP/g" `find /home/template/neople-tmp -type f -name "*.tbl"`
sed -i "s/DNF_DB_PORT/$DNF_DB_PORT/g" `find /home/template/neople-tmp -type f -name "*.tbl"`
# 替换Config.ini中的数据库地址
sed -i "s/DNF_DB_IP/$DNF_DB_IP/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/DNF_DB_PORT/$DNF_DB_PORT/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_ACCOUNT/$GM_ACCOUNT/g" `find /home/template/root-tmp -type f -name "*.ini"`
sed -i "s/GM_PASSWORD/$GM_PASSWORD/g" `find /home/template/root-tmp -type f -name "*.ini"`
# 将结果文件拷贝到对应目录
mv /home/template/neople-tmp /home/neople
mv /home/template/root-tmp /root
# 增加软链接[链接版本文件]
ln -s /data/Script.pvf /home/neople/game/Script.pvf

# 修改数据库IP和端口 & 刷新game账户权限只允许本地登录
mysql -u root -p$DNF_DB_ROOT_PASSWORD -P $DNF_DB_PORT -h $DNF_DB_IP <<EOF
UPDATE mysql.user SET Host='$DNF_DB_ALLOW_HOST' WHERE User='game';
flush privileges;
grant all privileges on *.* to 'game'@'$DNF_DB_ALLOW_HOST';
flush privileges;
use d_taiwan;
update db_connect set db_ip="$DNF_DB_IP", db_port="$DNF_DB_PORT";
select * from db_connect;
EOF

# 进入启动脚本目录
cd /root
# 启动程序
./run
