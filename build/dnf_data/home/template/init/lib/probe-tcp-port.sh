#!/bin/bash
# TCP 端口就绪探针, 端口取自环境变量
# 用法: probe-tcp-port.sh <端口变量名> [host]

portvar="$1"
host="${2:-127.0.0.1}"

if [ -z "$portvar" ]; then
    echo "probe-tcp-port: usage: probe-tcp-port.sh <port-env-var> [host]" >&2
    exit 2
fi
case "$portvar" in
*[!A-Za-z0-9_]*)
    echo "probe-tcp-port: invalid var name '$portvar'" >&2
    exit 2
    ;;
esac

port="${!portvar}"
# 端口未配置, 跳过监听直接返回就绪
[ -z "$port" ] && exit 0
case "$port" in
*[!0-9]*)
    echo "probe-tcp-port: $portvar='$port' is not a numeric port" >&2
    exit 1
    ;;
esac

socat -T2 /dev/null "TCP:${host}:${port},connect-timeout=2" >/dev/null 2>&1
