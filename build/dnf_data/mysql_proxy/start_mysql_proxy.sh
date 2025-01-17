#! /bin/bash

# 检查是否配置MYSQL地址
if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_PORT" ]; then
  # 代理本地3306端口并转发
  ./forward --forward 3306/$MYSQL_HOST:$MYSQL_PORT/tcp
else
    echo "no need to start mysql proxy"
fi
# 等待5秒后退出
sleep 5
