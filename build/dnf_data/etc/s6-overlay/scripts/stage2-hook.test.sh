#!/bin/bash
# stage2-hook.sh 测试脚本
# 校验 game_xxx / <svc>-log 服务 /
# 用 s6-rc-compile 验证服务端依赖关系是否正确

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/stage2-hook.sh"
SRC_PATH=$(cd -- "${SCRIPT_PATH}/.." &>/dev/null && pwd)

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

# 运行 stage2-hook, 用 S6_OVERLAY_PATH 绕过 with-contenv shebang
CENV="$WORK/container_env"
S6_OVERLAY_PATH="$WORK" CONTAINER_ENV_PATH="$CENV" \
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
chk "probes.d/game_siroco11 使用 env 探针" \
    "cmd:/home/template/init/lib/probe-tcp-port.sh GAME_SIROCO11_TCP_PORT" \
    "$(cat "$WORK/probes.d/game_siroco11" 2>/dev/null)"

# 每个常驻服务都应生成 <svc>-log
missing=""
for d in "$WORK"/s6-rc.d/*/; do
    s=$(basename "$d")
    case "$s" in *-log | game_template | user | dnf-bridge | dnf-channel) continue ;; esac
    [ -f "$d/type" ] && [ "$(cat "$d/type")" = longrun ] || continue
    [ -d "$WORK/s6-rc.d/${s}-log" ] || missing="${missing} ${s}:缺-log"
    [ -e "$WORK/s6-rc.d/${s}-log/dependencies.d/dnf-bootstrap" ] || missing="${missing} ${s}-log:缺dnf-bootstrap依赖"
    [ -e "$d/producer-for" ] || missing="${missing} ${s}:缺producer-for"
    [ "$(cat "$WORK/s6-rc.d/${s}-log/pipeline-name" 2>/dev/null)" = "${s}-pipeline" ] || missing="${missing} ${s}-log:缺pipeline-name"
    [ -e "$WORK/s6-rc.d/user/contents.d/${s}-pipeline" ] || missing="${missing} ${s}:pipeline未加入bundle"
    [ -e "$WORK/s6-rc.d/user/contents.d/${s}-log" ] && missing="${missing} ${s}-log:不应直接加入bundle"
done
chk "常驻服务均有带 dnf-bootstrap 依赖的 -log" "" "$missing"

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

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
