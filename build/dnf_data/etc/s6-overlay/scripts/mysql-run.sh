#!/bin/bash

# shellcheck source=/dev/null
source /home/template/init/lib/mysql.sh

if ! mysql_is_local; then
    echo "[mysql] no local mysql (external/server), idling"
    exec /command/s6-pause
fi

rm -f /var/lib/mysql/mysql.sock* /var/run/mysqld/*.pid 2>/dev/null

if ! mysql_write_init_sql /run/mysql/init.sql "$DNF_DB_ROOT_PASSWORD"; then
    echo "[mysql] failed to write init.sql" >&2
    exit 1
fi

# shellcheck source=/dev/null
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_64

exec env LD_PRELOAD="$(mysql_jemalloc_lib)" \
    /usr/sbin/mysqld --defaults-file=/etc/my.cnf --init-file=/run/mysql/init.sql --user=mysql
