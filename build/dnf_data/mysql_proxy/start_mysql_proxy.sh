#! /bin/bash

# 检查是否配置MYSQL地址
echo "CUR_SG_DB_HOST: $CUR_SG_DB_HOST, CUR_SG_DB_PORT: $CUR_SG_DB_PORT"
if [ -n "$CUR_SG_DB_HOST" ] && [ -n "$CUR_SG_DB_PORT" ]; then
  # 代理本地3306端口并转发
  ./forward --forward 3306/$CUR_SG_DB_HOST:$CUR_SG_DB_PORT/tcp
else
    echo "no need to start mysql proxy"
fi
# 等待5秒后退出
sleep 5
