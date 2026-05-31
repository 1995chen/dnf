#!/bin/bash

echo "CUR_SG_DB_HOST: $CUR_SG_DB_HOST, CUR_SG_DB_PORT: $CUR_SG_DB_PORT, proxy port: $CUR_SG_DB_PROXY_PORT"
if [ -n "$CUR_SG_DB_PROXY_PORT" ]; then
    socat "TCP-LISTEN:${CUR_SG_DB_PROXY_PORT},fork,reuseaddr" "TCP:$CUR_SG_DB_HOST:$CUR_SG_DB_PORT"
else
    echo "no need to start mysql proxy"
fi
