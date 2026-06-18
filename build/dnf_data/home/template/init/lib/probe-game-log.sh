#!/bin/bash

# 频道就绪探针
# 用法: probe-game-log.sh <channel_name> [log_root]
# 就绪返回 0, 未就绪返回 1, 参数错误返回 2

channel_name="$1"
log_root="${2:-/home/neople/game/log}"

if [ -z "$channel_name" ]; then
    echo "probe-game-log: usage: probe-game-log.sh <channel_name> [log_root]" >&2
    exit 2
fi
case "$channel_name" in
*[!A-Za-z0-9_]*)
    echo "probe-game-log: invalid channel name '$channel_name'" >&2
    exit 2
    ;;
esac

# 获取 df_game 启动时间
game_proc_start() {
    local cn="$1" pid t earliest=0
    if [ -n "$GAME_PROC_START_EPOCH" ]; then
        printf '%s' "$GAME_PROC_START_EPOCH"
        return 0
    fi
    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        t=$(stat -c %Y "/proc/$pid" 2>/dev/null) || continue
        if [ "$earliest" -eq 0 ] || [ "$t" -lt "$earliest" ]; then
            earliest="$t"
        fi
    done < <(pgrep -f "df_game_r ${cn} nofork" 2>/dev/null)
    printf '%s' "$earliest"
}

# df_game 进程不存在，未就绪
proc_start=$(game_proc_start "$channel_name")
case "$proc_start" in
'' | *[!0-9]*) proc_start=0 ;;
esac
[ "$proc_start" -gt 0 ] || exit 1

# 取 mtime 最新的 Log*.init
log_file=""
newest=0
for f in "$log_root/$channel_name"/Log*.init; do
    [ -f "$f" ] || continue
    m=$(stat -c %Y "$f" 2>/dev/null) || m=0
    if [ "$m" -ge "$newest" ]; then
        newest="$m"
        log_file="$f"
    fi
done

# 日志还没生成或为空, 未就绪
if [ -z "$log_file" ] || [ ! -s "$log_file" ]; then
    exit 1
fi

# 日志生成时间不早于进程启动时间, 排除上一轮残留
if [ "$newest" -lt "$proc_start" ]; then
    exit 1
fi

# 五国日志
for c in CN HK KR MO TW; do
    grep -q "GeoIP Allow Country Code : $c" "$log_file" || exit 1
done

# Monitor / Guild 连接日志
# grep -q '\[!\] Monitor Server Connected' "$log_file" || exit 1
# grep -q '\[!\] Guild Server Connected' "$log_file" || exit 1
# grep -q '\[!\] Connect To Monitor Server' "$log_file" || exit 1
# grep -q '\[!\] Connect To Guild Server' "$log_file" || exit 1
