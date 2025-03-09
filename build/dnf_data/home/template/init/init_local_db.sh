#! /bin/bash

# 判断本地数据库是否初始化过,端口号4000
if [ -z "$MAIN_MYSQL_HOST" ] && [ -z "$MAIN_MYSQL_PORT" ] && [ -z "$MYSQL_HOST" ] && [ -z "$MYSQL_PORT" ];then
  echo "use local mysql service"
  # 是否需要初始化
  if [ ! -d "/var/lib/mysql/mysql" ];then
    echo "prepare to init local mysql data....."
    # 清理数据
    rm -rf /var/lib/mysql/*
    # 启动mysql
    mysql_install_db --user=mysql
  else
    echo "local mysql data already inited."
  fi
  # 修改创建root账号
  service mysql start --skip-grant-tables
  mysql -u root <<EOF
    delete from mysql.user;
    flush privileges;
    grant all privileges on *.* to 'root'@'%' identified by '$DNF_DB_ROOT_PASSWORD' WITH GRANT OPTION;
    flush privileges;
EOF
  echo "update root password done."
  # 关闭服务
  service mysql stop
  # 赋予权限
  chmod 777 -R /var/lib/mysql
  echo "start local mysql...."
  service mysql start
fi
