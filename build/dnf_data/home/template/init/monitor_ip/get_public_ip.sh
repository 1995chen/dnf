#!/bin/bash

# 获取公网IPv4
# 注意：如果要修改url，需确保其curl输出结果为纯IP

OCTET='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
IP_REGEX="^${OCTET}(\.${OCTET}){3}$"

urls=(
    "https://v4.ident.me"
    "https://v4.ip.wtf"
    "https://ipv4.icanhazip.com"
    "https://api.ipify.org"
    "https://ifconfig.me"
    "https://ifconfig.io"
    "https://ipconfig.io"
    "https://checkip.amazonaws.com"
    "https://ip.sb"
    "https://ipecho.net/plain"
    "https://wtfismyip.com/text"
    "https://myip.wtf/text"
    "https://api.seeip.org"
    "https://l2.io/ip"
    "https://eth0.me"
    "https://myexternalip.com/raw"
    "https://ip.3322.net"
)

n=${#urls[@]}
start=$((RANDOM % n))
for i in $(seq 0 $((n - 1))); do
    idx=$(((start + i) % n))
    url="${urls[idx]}"
    ip=$(curl -fsS -4 --max-time 3 "$url" 2>/dev/null | tr -d '[:space:]')
    if [[ "$ip" =~ $IP_REGEX ]]; then
        echo "$ip"
        exit 0
    fi
done

exit 1
