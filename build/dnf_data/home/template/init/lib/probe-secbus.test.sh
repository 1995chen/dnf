#!/bin/bash
# probe-secbus.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROBE="${SCRIPT_PATH}/probe-secbus.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
ok() {
    local desc="$1"
    shift
    if "$@"; then pass=$((pass + 1)); else
        printf "FAIL %-52s (expected exit 0)\n" "$desc"
        failed=$((failed + 1))
    fi
}
no() {
    local desc="$1"
    shift
    if "$@"; then
        printf "FAIL %-52s (expected non-zero exit)\n" "$desc"
        failed=$((failed + 1))
    else pass=$((pass + 1)); fi
}

# 用法: mkbus <目录> <非空文件个数> [空文件个数]
mkbus() {
    local d="$1" full="$2" empty="${3:-0}" i
    mkdir -p "$d"
    for ((i = 1; i <= full; i++)); do head -c 2000 /dev/zero >"$d/sec_tss_sdk_bus_$i"; done
    for ((i = 1; i <= empty; i++)); do : >"$d/sec_tss_sdk_bus_e$i"; done
}

mkbus_nested() {
    local d="$1" full="$2" i
    mkdir -p "$d"
    for ((i = 1; i <= full; i++)); do head -c 2000 /dev/zero >"$d/tss_sdk_bus_$i"; done
}

# 用法: runp <want> <glob>
runp() { SECAGENT_CHANNEL_NUM="$1" SECBUS_GLOB="$2" SECBUS_GLOB_ALT='' bash "$PROBE"; }

echo "== 频道数从环境变量读取 =="
mkbus "$WORK/b3" 3
ok "want=3: 成功" runp 3 "$WORK/b3/sec_tss_sdk_bus_*"
mkbus "$WORK/b5" 5
ok "want=3: 成功" runp 3 "$WORK/b5/sec_tss_sdk_bus_*"
mkbus "$WORK/b2" 2
no "want=3: 失败" runp 3 "$WORK/b2/sec_tss_sdk_bus_*"

echo "== 不同 want 值 =="
mkbus "$WORK/b12" 12
ok "want=12 全部成功" runp 12 "$WORK/b12/sec_tss_sdk_bus_*"
no "want=12 失败 3 个" runp 12 "$WORK/b3/sec_tss_sdk_bus_*"
ok "want=1 成功 3 个" runp 1 "$WORK/b3/sec_tss_sdk_bus_*"

echo "== 环境变量为空时使用默认值 12 =="
ok "want 默认 12, 全部成功" \
    env SECAGENT_CHANNEL_NUM= SECBUS_GLOB="$WORK/b12/sec_tss_sdk_bus_*" SECBUS_GLOB_ALT='' bash "$PROBE"
no "want 默认 12, 失败 3 个" \
    env SECAGENT_CHANNEL_NUM= SECBUS_GLOB="$WORK/b3/sec_tss_sdk_bus_*" SECBUS_GLOB_ALT='' bash "$PROBE"

echo "== 忽略空 bus 文件 =="
mkbus "$WORK/bmix" 2 3
no "2 个非空 + 3 个空 < want 3" runp 3 "$WORK/bmix/sec_tss_sdk_bus_*"
mkbus "$WORK/bmix2" 3 2
ok "3 个非空 + 2 个空 >= want 3" runp 3 "$WORK/bmix2/sec_tss_sdk_bus_*"

echo "== 无 bus 文件 =="
no "无 bus 目录或文件: 失败" runp 3 "$WORK/none/sec_tss_sdk_bus_*"

echo "== want 参数非法时失败 =="
no "非数字: 失败" runp abc "$WORK/b3/sec_tss_sdk_bus_*"
no "want 不能为0" runp 0 "$WORK/b3/sec_tss_sdk_bus_*"

echo "== 嵌套 /dev/shm/sec/ =="
mkbus_nested "$WORK/nested3" 3
ok "SECBUS_GLOB_ALT 处理嵌套: 满足" \
    env SECAGENT_CHANNEL_NUM=3 SECBUS_GLOB="$WORK/none/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"
no "嵌套 < want: 失败" \
    env SECAGENT_CHANNEL_NUM=12 SECBUS_GLOB="$WORK/none/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"
ok "扁平 + 嵌套计入总数" \
    env SECAGENT_CHANNEL_NUM=5 SECBUS_GLOB="$WORK/b3/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"

echo "== bus 路径含空格与中文 =="
sp="$WORK/屏 障 中文"
mkbus "$sp" 3
ok "含空格与中文的 bus 目录计数" runp 3 "$sp/sec_tss_sdk_bus_*"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
