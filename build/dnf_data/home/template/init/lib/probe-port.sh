#!/bin/bash
# 服务端 TCP 就绪探针，端口从 server.cfg 的 this_tcp_port 读取。
#
# 用法: probe-port.sh <cfg-file> [host]

cfg="$1"
host="${2:-127.0.0.1}"

if [ -z "$cfg" ]; then
    echo "probe-port: usage: probe-port.sh <cfg-file> [host]" >&2
    exit 2
fi
if [ ! -r "$cfg" ]; then
    echo "probe-port: cannot read $cfg" >&2
    exit 1
fi

port=$(sed -n \
    's/^[[:space:]]*this_tcp_port[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "$cfg" | head -n1)

case "$port" in
'' | *[!0-9]*)
    echo "probe-port: this_tcp_port not found/numeric in $cfg" >&2
    exit 1
    ;;
esac

socat -T2 /dev/null "TCP:${host}:${port}" >/dev/null 2>&1
