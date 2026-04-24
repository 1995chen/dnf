#!/bin/bash

mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
chmod 750 /var/lib/mysql /var/run/mysqld
rm -rf /var/lib/mysql/*
/usr/local/mysql/bin/mysqld \
    --defaults-file=/etc/my.cnf \
    --initialize-insecure \
    --user=mysql \
    --basedir=/usr/local/mysql \
    --datadir=/var/lib/mysql \
    --explicit_defaults_for_timestamp
