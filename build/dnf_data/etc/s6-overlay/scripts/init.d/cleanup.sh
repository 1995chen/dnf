#!/command/with-contenv bash
# shellcheck shell=bash
# 清理上次启动残留的运行时文件，重建 /data 子目录，创建脚本软链接

# shellcheck source=../../../../home/template/init/lib/common.sh
source "${DNF_LIB_PATH:-/home/template/init/lib}/common.sh"

# 检查 持久化目录是否指向真实目录
for d in /data/s6-rc.d /data/dp \
    /data/log /data/log/netbird /data/log/tailscale \
    /data/monitor_ip /data/scheduler \
    /data/netbird /data/tailscale \
    /data/run /data/my.cnf.d; do
    normalize_data_path "$d" directory
done

rm -rf /var/lib/mysql/mysql.sock /var/lib/mysql/mysql.sock.lock \
    /var/lib/mysql/*.pid /var/lib/mysql/*.err \
    /var/run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock.lock /var/run/mysqld/*.pid \
    /data/monitor_ip/MONITOR_PUBLIC_IP /home/neople/game/log/* /dp2

[ -L /data/log ] || rm -rf /data/log/*

if ! mkdir -p /data/s6-rc.d /data/dp \
    /data/log/netbird /data/log/tailscale \
    /data/monitor_ip /data/scheduler \
    /data/netbird /data/tailscale \
    /data/run /data/my.cnf.d; then
    echo "ERROR: failed to create /data subdirectories" >&2
    exit 1
fi

ln -sf /data/dp /dp2
ln -sf /home/template/init/scheduler/db-tool.sh /usr/bin/db-tool
