#! /bin/bash

# 清除mysql sock以及pid文件
rm -rf /var/lib/mysql/mysql.sock
rm -rf /var/lib/mysql/*.pid
rm -rf /var/lib/mysql/*.err

# 初始化数据
if [ ! -d "/var/lib/mysql/mysql" ];then
  echo "prepare to init local mysql data....."
  # 清理数据
  rm -rf /var/lib/mysql/*
  # 启动mysql
  mysql_install_db --user=mysql
  service mysql start
  /usr/bin/mysqladmin -u root password $DNF_DB_ROOT_PASSWORD
  service mysql stop      
else
  echo "local mysql data already inited."
fi
echo "local mysql service flush privileges....."
service mysql start --skip-grant-tables
# 删除用户后需要立即刷新,否则无法创建root用户
mysql -u root <<EOF
delete from mysql.user;
flush privileges;
grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
flush privileges;
select user,host,password from mysql.user;
EOF
# 关闭服务
service mysql stop
# 赋予权限
chmod 777 -R /var/lib/mysql
/usr/bin/mysqld_safe --datadir=/var/lib/mysql --pid-file=/var/lib/mysql/$(hostname).pid
