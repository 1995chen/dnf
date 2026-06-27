#! /bin/bash

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
fi
# 检查PUBLIC IP
if [ -z "$PUBLIC_IP" ] && [ -n "$TS_AUTH_KEY" ] && [ -n "$TS_LOGIN_SERVER" ]; then
    /usr/bin/tailscaled --state=/data/tailscale/tailscaled.state --socket=/data/tailscale/tailscaled.sock --tun=tailscale0
else
    echo "no need to start tailscaled"
fi
# 等待5秒后退出
sleep 5
