#!/bin/bash
# zergsvr 就绪探针
# 解析 zergsvrd.xml 的 self_svr_info，获取 (svr_type, svr_id)
# 再解析 svcid.xml，按 (type, id) 获取监听端口
# 注意 zergsvrd.xml 用 <svr_type>/<svr_id>, svcid.xml 用 <svr_type_>/<svr_id_>
#
# 用法: probe-zerg-listen.sh <zergsvrd.xml> <svcid.xml> [host]

zcfg="$1"
scfg="$2"
host="${3:-127.0.0.1}"

if [ -z "$zcfg" ] || [ -z "$scfg" ]; then
    echo "probe-zerg-listen: usage: probe-zerg-listen.sh <zergsvrd.xml> <svcid.xml> [host]" >&2
    exit 2
fi
if [ ! -r "$zcfg" ]; then
    echo "probe-zerg-listen: cannot read $zcfg" >&2
    exit 1
fi
if [ ! -r "$scfg" ]; then
    echo "probe-zerg-listen: cannot read $scfg" >&2
    exit 1
fi

# 从 self_svr_info 获取 svr_type 和 svr_id
self=$(awk '
    function num(s) { sub(/^[^>]*>/, "", s); sub(/<.*/, "", s); gsub(/[^0-9]/, "", s); return s }
    /<self_svr_info[[:space:]>]/ { in_self = 1 }
    in_self && /<svr_type[[:space:]>]/ { t = num($0) }
    in_self && /<svr_id[[:space:]>]/   { i = num($0) }
    /<\/self_svr_info>/ { if (in_self) { print t, i; exit } }
' "$zcfg")
self_type="${self%% *}"
self_id="${self##* }"
case "$self_type" in
'' | *[!0-9]*)
    echo "probe-zerg-listen: no svr_type in self_svr_info of $zcfg" >&2
    exit 1
    ;;
esac
case "$self_id" in
'' | *[!0-9]*)
    echo "probe-zerg-listen: no svr_id in self_svr_info of $zcfg" >&2
    exit 1
    ;;
esac

# 解析 svcid.xml，按 (type, id) 获取监听端口
port=$(awk -v wt="$self_type" -v wi="$self_id" '
    function num(s) { sub(/^[^>]*>/, "", s); sub(/<.*/, "", s); gsub(/[^0-9]/, "", s); return s }
    /<service_info_[[:space:]>]/ { ct = ""; ci = "" }
    /<svr_type_[[:space:]>]/ { ct = num($0) }
    /<svr_id_[[:space:]>]/   { ci = num($0) }
    /<svr_port_[[:space:]>]/ { p = num($0); if (ct == wt && ci == wi) { print p; exit } }
' "$scfg")
case "$port" in
'' | *[!0-9]*)
    echo "probe-zerg-listen: no port for self (type=$self_type, id=$self_id) in $scfg" >&2
    exit 1
    ;;
esac

socat -T2 /dev/null "TCP:${host}:${port},connect-timeout=2" >/dev/null 2>&1
