#!/bin/bash

if [ -z "$GAME_SERVER_IP" ]; then
    GAME_SERVER_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null)
    if [ -z "$GAME_SERVER_IP" ]; then
        echo "ERROR: MONITOR_PUBLIC_IP empty, cannot start dnf-gate-server" >&2
        exit 1
    fi
fi
export GAME_SERVER_IP

export DB_HOST="$CUR_MAIN_DB_HOST"
export DB_PORT="$CUR_MAIN_DB_PORT"
export DB_PASSWORD="$DNF_DB_GAME_PASSWORD"
export AES_KEY="$GATE_AES_KEY"
export BIND_ADDRESS="$GATE_BIND_ADDRESS"
export RUST_LOG="$GATE_RUST_LOG"
export TLS_BIND_ADDRESS="$GATE_TLS_BIND_ADDRESS"
export TLS_ONLY="$GATE_TLS_ONLY"
export REGISTRATION_OPEN="$GATE_REGISTRATION_OPEN"
[ -n "$GATE_TLS_CERT_PATH" ] && export TLS_CERT_PATH="$GATE_TLS_CERT_PATH"
[ -n "$GATE_TLS_KEY_PATH" ] && export TLS_KEY_PATH="$GATE_TLS_KEY_PATH"

exec /usr/bin/dnf-gate-server
