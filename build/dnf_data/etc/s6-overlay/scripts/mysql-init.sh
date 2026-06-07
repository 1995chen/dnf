#!/bin/bash

# shellcheck source=/dev/null
source /home/template/init/lib/mysql.sh

if ! mysql_is_local; then
    echo "[mysql-init] no local mysql (external/server), skip"
    exit 0
fi

if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mysql-init] initializing local mysql data dir..."
    rm -rf /var/lib/mysql/*
    if ! mysql_first_boot_init; then
        echo "[mysql-init] first boot init failed" >&2
        exit 1
    fi
else
    echo "[mysql-init] local mysql data already initialized"
fi

if ! chown -R mysql:mysql /var/lib/mysql; then
    echo "[mysql-init] chown failed" >&2
    exit 1
fi
