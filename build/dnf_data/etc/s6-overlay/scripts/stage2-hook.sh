#!/command/with-contenv bash
# shellcheck shell=bash

s6rc_path="${S6_OVERLAY_PATH:-/etc/s6-overlay}/s6-rc.d"
probes_path="${S6_OVERLAY_PATH:-/etc/s6-overlay}/probes.d"
container_env_path="${CONTAINER_ENV_PATH:-/run/s6/container_environment}"
lib_path="${DNF_LIB_PATH:-/home/template/init/lib}"

source "$lib_path/common.sh"

# SERVER_GROUP_NAME
# shellcheck disable=SC2034
SERVER_GROUP_NAME_1="cain"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_2="diregie"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_3="siroco"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_4="prey"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_5="casillas"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_6="hilder"

# 去除 SERVER_GROUP / OPEN_CHANNEL 前后的引号
SERVER_GROUP="${SERVER_GROUP//\'/}"
SERVER_GROUP="${SERVER_GROUP//\"/}"
OPEN_CHANNEL="${OPEN_CHANNEL//\'/}"
OPEN_CHANNEL="${OPEN_CHANNEL//\"/}"

if [ -z "$SERVER_GROUP" ] || [ "$SERVER_GROUP" -lt 1 ] || [ "$SERVER_GROUP" -gt 6 ] 2>/dev/null; then
    echo "[stage2-hook] invalid SERVER_GROUP: '$SERVER_GROUP', skipping dynamic generation" >&2
    exit 0
fi
SERVER_GROUP_NAME_VAR="SERVER_GROUP_NAME_$SERVER_GROUP"
SERVER_GROUP_NAME=${!SERVER_GROUP_NAME_VAR}

# 清理上次启动残留的 game_${SERVER_GROUP_NAME}*
find "${s6rc_path}" -maxdepth 1 -type d -name "game_${SERVER_GROUP_NAME}*" \
    -not -name 'game_template' -exec rm -rf {} +
find "${s6rc_path}/user/contents.d" -maxdepth 1 -type f \
    -name "game_${SERVER_GROUP_NAME}*" -delete
find "${s6rc_path}/dnf-channel/contents.d" -maxdepth 1 -type f \
    -name "game_${SERVER_GROUP_NAME}*" -delete
find "${probes_path}" -maxdepth 1 -type f \
    -name "game_${SERVER_GROUP_NAME}*" -delete
find "${container_env_path}" -maxdepth 1 -type f \
    -name "GAME_${SERVER_GROUP_NAME^^}*_TCP_PORT" -delete 2>/dev/null

# 根据 OPEN_CHANNEL 生成 game_xxx 频道目录
while IFS= read -r num; do
    [ -n "$num" ] || continue
    if [ "$num" -ge 11 ] && [ "$num" -le 51 ]; then
        process_sequence=3
    else
        process_sequence=5
    fi
    if [ "$num" -lt 10 ]; then
        num="0$num"
    fi
    svc="game_${SERVER_GROUP_NAME}${num}"
    dst=${s6rc_path}/$svc

    if ! cp -a "${s6rc_path}/game_template" "$dst"; then
        echo "[stage2-hook] failed to create $svc, skipping" >&2
        continue
    fi
    sed -i \
        -e "s/__SVC_NAME__/${svc}/g" \
        -e "s/__CHANNEL_NUM__/${num}/g" \
        -e "s/__PROCESS_SEQ__/${process_sequence}/g" \
        "$dst/run"
    chmod +x "$dst/run"

    : >"${s6rc_path}/user/contents.d/$svc"
    : >"${s6rc_path}/dnf-channel/contents.d/$svc"

    game_port="${SERVER_GROUP}00${num}"
    game_port_var="${svc^^}_TCP_PORT"
    mkdir -p "${container_env_path}"
    printf '%s' "$game_port" >"${container_env_path}/${game_port_var}"

    channel_name="${SERVER_GROUP_NAME}${num}"
    printf 'cmd:/home/template/init/lib/probe-tcp-port.sh %s;cmd:/home/template/init/lib/probe-game-log.sh %s\n' \
        "$game_port_var" "$channel_name" >"${probes_path}/$svc"
done < <(enumerate_open_channels "$OPEN_CHANNEL")

# 合并 /data/s6-rc.d/ 下的用户自定义配置
if [ -d /data/s6-rc.d ]; then
    for plugin_path in /data/s6-rc.d/*/; do
        [ -d "$plugin_path" ] || continue
        plugin_name=$(basename "$plugin_path")
        # 与内置服务同名则跳过
        if [ -e "${s6rc_path}/$plugin_name" ]; then
            echo "[stage2-hook] plugin name conflicts with built-in: $plugin_name, skipping" >&2
            continue
        fi
        if ! cp -a "$plugin_path" "${s6rc_path}/$plugin_name"; then
            echo "[stage2-hook] failed to merge plugin $plugin_name, skipping" >&2
            continue
        fi

        ptype=$(cat "${s6rc_path}/$plugin_name/type" 2>/dev/null)
        if [ "$ptype" = longrun ] || [ "$ptype" = oneshot ]; then
            mkdir -p "${s6rc_path}/$plugin_name/dependencies.d"
            : >"${s6rc_path}/$plugin_name/dependencies.d/env-resolve"
            : >"${s6rc_path}/$plugin_name/dependencies.d/cleanup"
        fi
        if [ ! -e "$plugin_path/.disabled" ]; then
            : >"${s6rc_path}/user/contents.d/$plugin_name"
        fi
    done
fi

# 每个服务把日志写到 /data/log/<svc>/current
# 单个日志文件最大 1MiB，最多保留 10 个日志
add_log_subservice() {
    local svc="$1"
    local log_svc="${svc}-log"
    local main_path="${s6rc_path}/$svc"
    local log_path="${s6rc_path}/$log_svc"

    [ -e "$log_path" ] && return 0
    [ -f "$main_path/type" ] || return 0
    [ "$(cat "$main_path/type")" = "longrun" ] || return 0

    [ -e "$main_path/producer-for" ] && return 0

    mkdir -p "$log_path"
    echo longrun >"$log_path/type"
    printf '%s\n' "$svc" >"$log_path/consumer-for"
    printf '%s\n' "$log_svc" >"$main_path/producer-for"
    printf '%s\n' "${svc}-pipeline" >"$log_path/pipeline-name"
    printf '3\n' >"$log_path/notification-fd"

    # 依赖 cleanup, 确保在 cleanup 的 rm -rf /data/log/* 之后启动,
    # 否则 s6-log 建好日志目录后会被 cleanup 删掉, 日志写进已删除的 inode。
    mkdir -p "$log_path/dependencies.d"
    : >"$log_path/dependencies.d/cleanup"

    cat >"$log_path/run" <<EOF
#!/bin/bash
mkdir -p /data/log/${svc}
chmod 0755 /data/log/${svc} 2>/dev/null || true
exec s6-log -bd3 -- T n10 s1048576 /data/log/${svc}
EOF
    chmod +x "$log_path/run"
    : >"${s6rc_path}/user/contents.d/${svc}-pipeline"
}

for entry in "${s6rc_path}"/*/; do
    svc=$(basename "$entry")
    case "$svc" in
    *-log) continue ;;
    game_template) continue ;;
    user | dnf-bridge | dnf-channel) continue ;;
    esac
    add_log_subservice "$svc"
done

echo "[stage2-hook] dynamic services prepared"
