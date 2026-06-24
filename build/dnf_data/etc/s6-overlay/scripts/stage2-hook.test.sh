#!/bin/bash
# stage2-hook.sh 测试脚本
# 校验 game_xxx / <svc>-log 服务 /
# 用 s6-rc-compile 验证服务端依赖关系是否正确

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/stage2-hook.sh"
SRC_PATH=$(cd -- "${SCRIPT_PATH}/.." &>/dev/null && pwd)
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../../../home/template/init/lib" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -a "${SRC_PATH}/s6-rc.d" "${WORK}/s6-rc.d"
cp -a "${SRC_PATH}/probes.d" "${WORK}/probes.d"

mkdir -p "${WORK}/s6-rc.d/base/contents.d"
echo bundle >"${WORK}/s6-rc.d/base/type"

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-44s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}

chk_has() {
    case "$3" in
    *"$2"*) pass=$((pass + 1)) ;;
    *)
        printf "FAIL %-44s missing [%s]\n" "$1" "$2"
        failed=1
        ;;
    esac
}

# 生成测试的 s6-rc.d 目录并返回路径
setup_work() {
    local w
    w=$(mktemp -d)
    cp -a "${SRC_PATH}/s6-rc.d" "${w}/s6-rc.d"
    cp -a "${SRC_PATH}/probes.d" "${w}/probes.d"
    mkdir -p "${w}/s6-rc.d/base/contents.d"
    echo bundle >"${w}/s6-rc.d/base/type"
    printf '%s' "$w"
}

# 获取 run 文件里 -T 的值
run_probe_timeout() {
    grep -oE -- '-T [0-9]+' "$1" 2>/dev/null | awk '{print $2}'
}

# 运行 stage2-hook, 用 S6_OVERLAY_PATH 绕过 with-contenv shebang
CENV="$WORK/container_env"
S6_OVERLAY_PATH="$WORK" CONTAINER_ENV_PATH="$CENV" DNF_LIB_PATH="$LIB_PATH" \
    SERVER_GROUP=3 OPEN_CHANNEL='11,52' bash "$HOOK" >/dev/null 2>&1
chk "stage2-hook 退出码" 0 "$?"

# 动态生成 game_xxx 配置
chk "生成 game_siroco11" yes "$([ -d "$WORK/s6-rc.d/game_siroco11" ] && echo yes || echo no)"
chk "生成 game_siroco52" yes "$([ -d "$WORK/s6-rc.d/game_siroco52" ] && echo yes || echo no)"
chk "生成 probes.d/game_siroco11" yes "$([ -f "$WORK/probes.d/game_siroco11" ] && echo yes || echo no)"
chk "替换 game run 占位符" 0 "$(grep -c '__[A-Z_]*__' "$WORK/s6-rc.d/game_siroco11/run" 2>/dev/null)"
chk "设置 game_siroco11 默认启动" yes "$([ -f "$WORK/s6-rc.d/user/contents.d/game_siroco11" ] && echo yes || echo no)"

# 频道端口环境变量 = SERVER_GROUP00<频道号>
chk "game_siroco11 端口环境变量" "30011" "$(cat "$CENV/GAME_SIROCO11_TCP_PORT" 2>/dev/null)"
chk "game_siroco52 端口环境变量" "30052" "$(cat "$CENV/GAME_SIROCO52_TCP_PORT" 2>/dev/null)"

# 频道就绪探针
chk "probes.d/game_siroco11 端口+日志探针" \
    "cmd:/home/template/init/lib/probe-tcp-port.sh GAME_SIROCO11_TCP_PORT;cmd:/home/template/init/lib/probe-game-log.sh siroco11" \
    "$(cat "$WORK/probes.d/game_siroco11" 2>/dev/null)"
chk "probes.d/game_siroco52 端口+日志探针" \
    "cmd:/home/template/init/lib/probe-tcp-port.sh GAME_SIROCO52_TCP_PORT;cmd:/home/template/init/lib/probe-game-log.sh siroco52" \
    "$(cat "$WORK/probes.d/game_siroco52" 2>/dev/null)"

# 每个常驻服务都应生成 <svc>-log
missing=""
for d in "$WORK"/s6-rc.d/*/; do
    s=$(basename "$d")
    case "$s" in *-log | game_template | user | dnf-bridge | dnf-channel) continue ;; esac
    [ -f "$d/type" ] && [ "$(cat "$d/type")" = longrun ] || continue
    [ -d "$WORK/s6-rc.d/${s}-log" ] || missing="${missing} ${s}:缺-log"
    [ -e "$WORK/s6-rc.d/${s}-log/dependencies.d/cleanup" ] || missing="${missing} ${s}-log:缺cleanup依赖"
    [ -e "$d/producer-for" ] || missing="${missing} ${s}:缺producer-for"
    [ "$(cat "$WORK/s6-rc.d/${s}-log/pipeline-name" 2>/dev/null)" = "${s}-pipeline" ] || missing="${missing} ${s}-log:缺pipeline-name"
    [ -e "$WORK/s6-rc.d/user/contents.d/${s}-pipeline" ] || missing="${missing} ${s}:pipeline未加入bundle"
    [ -e "$WORK/s6-rc.d/user/contents.d/${s}-log" ] && missing="${missing} ${s}-log:不应直接加入bundle"
done
chk "常驻服务均有带 cleanup 依赖的 -log" "" "$missing"

# 用 s6-rc-compile 验证服务端依赖关系正确性
if command -v s6-rc-compile >/dev/null 2>&1; then
    if err=$(s6-rc-compile "$WORK/compiled" "$WORK/s6-rc.d" 2>&1); then
        pass=$((pass + 1))
    else
        printf "FAIL %-44s s6-rc-compile 失败:\n" "依赖图编译"
        printf '%s\n' "$err" | sed 's/^/    /'
        failed=1
    fi
else
    echo "skip: 未安装 s6-rc-compile, 跳过编译校验"
fi

# PROBE_TIMEOUT: 更新所有服务探针的 timeout-up 与 run -T 时间
W=$(setup_work)
hook_out=$(S6_OVERLAY_PATH="$W" CONTAINER_ENV_PATH="$W/cenv" DNF_LIB_PATH="$LIB_PATH" \
    SERVER_GROUP=3 OPEN_CHANNEL='11' PROBE_TIMEOUT=1234 bash "$HOOK" 2>/dev/null)
chk_has "PROBE_TIMEOUT: 显示超时时间更新日志" "probe timeout = 1234s (PROBE_TIMEOUT override)" "$hook_out"
bad=""
for d in "$W"/s6-rc.d/*/; do
    [ -f "${d}timeout-up" ] || continue
    [ "$(cat "${d}timeout-up")" = "1234000" ] || bad="${bad} $(basename "$d"):tu=$(cat "${d}timeout-up")"
    if grep -q notifyoncheck "${d}run" 2>/dev/null; then
        [ "$(run_probe_timeout "${d}run")" = "1234000" ] || bad="${bad} $(basename "$d"):T=$(run_probe_timeout "${d}run")"
    fi
done
chk "PROBE_TIMEOUT 更新所有探针 timeout-up 与 -T" "" "$bad"
chk "动态生成的频道 timeout-up 会继承模板超时时间" "1234000" "$(cat "$W/s6-rc.d/game_siroco11/timeout-up" 2>/dev/null)"
chk "动态生成的频道 run -T 会继承模板超时时间" "1234000" "$(run_probe_timeout "$W/s6-rc.d/game_siroco11/run")"
rm -rf "$W"

# nano 超时时间: 1800s
W=$(setup_work)
hook_out=$(S6_OVERLAY_PATH="$W" CONTAINER_ENV_PATH="$W/cenv" DNF_LIB_PATH="$LIB_PATH" \
    SERVER_GROUP=3 OPEN_CHANNEL='11' TUNE_PROFILE=nano bash "$HOOK" 2>/dev/null)
chk_has "nano: 显示超时时间日志与性能配置" "probe timeout = 1800s (profile=nano)" "$hook_out"
chk "nano channel timeout-up=1800000" "1800000" "$(cat "$W/s6-rc.d/channel/timeout-up" 2>/dev/null)"
chk "nano channel run -T=1800000" "1800000" "$(run_probe_timeout "$W/s6-rc.d/channel/run")"
chk "nano 频道 timeout-up=1800000" "1800000" "$(cat "$W/s6-rc.d/game_siroco11/timeout-up" 2>/dev/null)"
rm -rf "$W"

# micro 超时时间: 900s
W=$(setup_work)
S6_OVERLAY_PATH="$W" CONTAINER_ENV_PATH="$W/cenv" DNF_LIB_PATH="$LIB_PATH" \
    SERVER_GROUP=3 OPEN_CHANNEL='11' TUNE_PROFILE=micro bash "$HOOK" >/dev/null 2>&1
chk "micro channel timeout-up=900000" "900000" "$(cat "$W/s6-rc.d/channel/timeout-up" 2>/dev/null)"
rm -rf "$W"

# large 超时时间: 600s
W=$(setup_work)
S6_OVERLAY_PATH="$W" CONTAINER_ENV_PATH="$W/cenv" DNF_LIB_PATH="$LIB_PATH" \
    SERVER_GROUP=3 OPEN_CHANNEL='11' TUNE_PROFILE=large bash "$HOOK" >/dev/null 2>&1
chk "large channel timeout-up=600000" "600000" "$(cat "$W/s6-rc.d/channel/timeout-up" 2>/dev/null)"
rm -rf "$W"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
