#!/bin/bash

if [ -z "$GAME_SERVER_IP" ]; then
    GAME_SERVER_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null)
    if [ -z "$GAME_SERVER_IP" ]; then
        echo "ERROR: MONITOR_PUBLIC_IP empty, cannot start dnf-gate-server" >&2
        exit 1
    fi
fi
export GAME_SERVER_IP

exec /usr/bin/dnf-gate-server
