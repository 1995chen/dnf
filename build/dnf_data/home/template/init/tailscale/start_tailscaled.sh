#! /bin/bash

# 检查PUBLIC IP
if [ -z "$PUBLIC_IP" ] && [ -n "$TS_AUTH_KEY" ] && [ -n "$TS_LOGIN_SERVER" ]; then
    /usr/bin/tailscaled --state=/data/tailscale/tailscaled.state --socket=/data/tailscale/tailscaled.sock --tun=userspace-networking
else
    echo "no need to start tailscaled"
fi
# 等待5秒后退出
sleep 5
