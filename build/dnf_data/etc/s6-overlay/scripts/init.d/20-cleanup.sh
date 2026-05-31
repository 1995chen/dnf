#!/command/with-contenv bash
# shellcheck shell=bash
# 清理上次启动残留的运行时文件，重建 /data 子目录

# MySQL 残留
rm -f /var/lib/mysql/mysql.sock /var/lib/mysql/mysql.sock.lock \
    /var/lib/mysql/*.pid /var/lib/mysql/*.err \
    /var/run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock.lock \
    /var/run/mysqld/*.pid

# IP 文件每次启动由 monitor_ip 重写
rm -rf /data/monitor_ip/MONITOR_PUBLIC_IP

# 各频道的日志目录
for i in {1..52}; do
    rm -rf "/home/neople/game/log/diregie$(printf "%02d" "$i")"/*
    rm -rf "/home/neople/game/log/cain$(printf "%02d" "$i")"/*
    rm -rf "/home/neople/game/log/siroco$(printf "%02d" "$i")"/*
done

rm -rf /data/log/*
rm -rf /home/neople/game/log/*
rm -rf /dp2

# /data 子目录
mkdir -p /data/s6-rc.d
mkdir -p /data/dp
ln -s /data/dp /dp2
mkdir -p /data/log /data/log/netbird /data/log/tailscale
mkdir -p /data/monitor_ip
mkdir -p /data/scheduler
mkdir -p /data/netbird /data/tailscale
mkdir -p /data/run
