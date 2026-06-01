#!/bin/bash

source /home/template/init/lib/common.sh

# 获得频道传入参数
channel_no=$1
process_sequence=$2
channel_name="${SERVER_GROUP_NAME}${channel_no}"

echo "channel_name is $channel_name"
echo "prepare to start ch.$channel_no, process_sequence is $process_sequence"
MONITOR_PUBLIC_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null)
if [ -z "$MONITOR_PUBLIC_IP" ]; then
    echo "ERROR: MONITOR_PUBLIC_IP empty, cannot start game" >&2
    exit 1
fi
echo "MONITOR_PUBLIC_IP is $MONITOR_PUBLIC_IP"
# 生成配置文件
rm -rf "/tmp/${channel_name}.cfg"
cp /home/template/neople/game/cfg/server.template "/tmp/${channel_name}.cfg"
safe_sed "__MAIN_BRIDGE_IP__" "$MAIN_BRIDGE_IP" "/tmp/${channel_name}.cfg"
safe_sed "__CHANNEL_NO__" "$channel_no" "/tmp/${channel_name}.cfg"
safe_sed "__PROCESS_SEQUENCE__" "$process_sequence" "/tmp/${channel_name}.cfg"
safe_sed "__PUBLIC_IP__" "$MONITOR_PUBLIC_IP" "/tmp/${channel_name}.cfg"
safe_sed "__DEC_GAME_PWD__" "$DEC_GAME_PWD" "/tmp/${channel_name}.cfg"
safe_sed "__SERVER_GROUP__" "$SERVER_GROUP" "/tmp/${channel_name}.cfg"
substitute_port_markers "/tmp/${channel_name}.cfg"
cp "/tmp/${channel_name}.cfg" "/home/neople/game/cfg/${channel_name}.cfg"
echo "generate ${channel_name}.cfg success"
# 清理cfg文件
rm -rf "/tmp/${channel_name}.cfg"
# 启动服务
old_pid=$(pgrep -f "df_game_r $channel_name nofork")
echo "ch.$channel_no old pid is $old_pid"
if [ -n "$old_pid" ]; then
    echo "old pid not empty, kill $old_pid"
    kill -9 "$old_pid"
fi
rm -rf "pid/${channel_name}.pid"

# shellcheck source=../lib/tune.sh
source /home/template/init/lib/tune.sh
tune_apply_malloc_conf_32
# 加载DP并启动，确保DP路径已经被正确映射
exec env LD_PRELOAD="/usr/lib/libjemalloc32.so.2:/usr/lib/libglibc_compat.so:/dp2/libhook.so:/home/neople/game/frida.so" \
    ./df_game_r "$channel_name" nofork
