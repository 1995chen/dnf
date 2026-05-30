#!/bin/bash
# 服务端 TCP 就绪探针，端口从 cfg 文件读取。
#
# 用法: probe-port.sh <cfg-file> [host] [port-field]

cfg="$1"
host="${2:-127.0.0.1}"
field="${3:-this_tcp_port}"

if [ -z "$cfg" ]; then
    echo "probe-port: usage: probe-port.sh <cfg-file> [host] [port-field]" >&2
    exit 2
fi
if [ ! -r "$cfg" ]; then
    echo "probe-port: cannot read $cfg" >&2
    exit 1
fi
case "$field" in
'' | *[!A-Za-z0-9_]*)
    echo "probe-port: invalid port-field '$field'" >&2
    exit 2
    ;;
esac

port=$(sed -n \
    "s/^[[:space:]]*[0-9.]*${field}[[:space:]]*=\{0,1\}[[:space:]]*\([0-9][0-9]*\)\([[:space:]].*\)\{0,1\}$/\1/p" \
    "$cfg" | head -n1)

case "$port" in
'' | *[!0-9]*)
    echo "probe-port: $field not found/numeric in $cfg" >&2
    exit 1
    ;;
esac

socat -T2 /dev/null "TCP:${host}:${port},connect-timeout=2" >/dev/null 2>&1
