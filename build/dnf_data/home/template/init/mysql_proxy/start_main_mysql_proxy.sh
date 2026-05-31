#!/bin/bash

echo "CUR_MAIN_DB_HOST: $CUR_MAIN_DB_HOST, CUR_MAIN_DB_PORT: $CUR_MAIN_DB_PORT, proxy port: $CUR_MAIN_DB_PROXY_PORT"
if [ -n "$CUR_MAIN_DB_PROXY_PORT" ]; then
    socat "TCP-LISTEN:${CUR_MAIN_DB_PROXY_PORT},fork,reuseaddr" "TCP:$CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT"
else
    echo "no need to start master mysql proxy"
fi
