#!/bin/bash

source /home/template/init/lib/common.sh

# GAME_SERVER_IP为空时，等待monitor_ip.sh解析到真实IP后再启动
if [ -z "$GAME_SERVER_IP" ]; then
    if ! GAME_SERVER_IP=$(wait_for_monitor_ip); then
        echo "ERROR: timeout waiting for MONITOR_PUBLIC_IP, cannot start dnf-gate-server" >&2
        exit 1
    fi
fi
export GAME_SERVER_IP

exec /usr/bin/dnf-gate-server
