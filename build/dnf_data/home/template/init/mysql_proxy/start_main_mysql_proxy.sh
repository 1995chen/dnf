#! /bin/bash

# 检查是否配置主MYSQL地址
echo "CUR_MAIN_DB_HOST: $CUR_MAIN_DB_HOST, CUR_MAIN_DB_PORT: $CUR_MAIN_DB_PORT"
if [ -n "$CUR_MAIN_DB_HOST" ] && [ -n "$CUR_MAIN_DB_PORT" ]; then
  # 代理本地3307端口并转发
  socat TCP-LISTEN:3307,fork,reuseaddr TCP:$CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT
else
    echo "no need to start master mysql proxy"
fi
# 等待5秒后退出
sleep 5
