#! /bin/bash

# 检查PUBLIC IP
if [ -z "$PUBLIC_IP" ] && [ -n "$TS_AUTH_KEY" ] && [ -n "$TS_LOGIN_SERVER" ]; then
    /usr/bin/tailscale --socket=/data/tailscale/tailscaled.sock up --login-server="$TS_LOGIN_SERVER" --authkey="$TS_AUTH_KEY"
else
    echo "no need to start tailscale"
fi
# 等待5秒后退出
sleep 5
