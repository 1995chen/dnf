#!/bin/bash

if [ "$1" = "mysql" ]; then
    shift
    /etc/init.d/mysql "$@"
else
    echo "Unknown service: $1"
    exit 1
fi
