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

# 用法:
# mkcfg <文件> <数字|RAW:文本>
mkcfg() {
    local f="$1" v="$2"
    case "$v" in
    RAW:*) printf '%s\n' "${v#RAW:}" >"$f" ;;
    *) printf '<config>\n  <gamesvr_channel_num_>%s</gamesvr_channel_num_>\n</config>\n' "$v" >"$f" ;;
    esac
}

# 用法:
# mkbus <目录> <非空文件个数> [空文件个数]
mkbus() {
    local d="$1" full="$2" empty="${3:-0}" i
    mkdir -p "$d"
    for ((i = 1; i <= full; i++)); do head -c 2000 /dev/zero >"$d/sec_tss_sdk_bus_$i"; done
    for ((i = 1; i <= empty; i++)); do : >"$d/sec_tss_sdk_bus_e$i"; done
}
runp() { SECAGENT_CONFIG="$1" SECBUS_GLOB="$2" SECBUS_GLOB_ALT= bash "$PROBE"; }
mkbus_nested() {
    local d="$1" full="$2" i
    mkdir -p "$d"
    for ((i = 1; i <= full; i++)); do head -c 2000 /dev/zero >"$d/tss_sdk_bus_$i"; done
}

echo "== dynamic count from gamesvr_channel_num_ =="
mkcfg "$WORK/c3.xml" 3
mkbus "$WORK/b3" 3
ok "exact count satisfies" runp "$WORK/c3.xml" "$WORK/b3/sec_tss_sdk_bus_*"
mkbus "$WORK/b5" 5
ok "more than required still ok" runp "$WORK/c3.xml" "$WORK/b5/sec_tss_sdk_bus_*"
mkbus "$WORK/b2" 2
no "fewer than required fails" runp "$WORK/c3.xml" "$WORK/b2/sec_tss_sdk_bus_*"

echo "== different config value, no hardcode =="
mkcfg "$WORK/c12.xml" 12
mkbus "$WORK/b12" 12
ok "config=12 with 12 buses ok" runp "$WORK/c12.xml" "$WORK/b12/sec_tss_sdk_bus_*"
no "config=12 with 3 buses fails" runp "$WORK/c12.xml" "$WORK/b3/sec_tss_sdk_bus_*"
mkcfg "$WORK/c1.xml" 1
ok "config=1 with 3 buses ok" runp "$WORK/c1.xml" "$WORK/b3/sec_tss_sdk_bus_*"

echo "== empty (0-byte) bus objects do not count =="
mkbus "$WORK/bmix" 2 3
no "2 full + 3 empty < want 3" runp "$WORK/c3.xml" "$WORK/bmix/sec_tss_sdk_bus_*"
mkbus "$WORK/bmix2" 3 2
ok "3 full + 2 empty >= want 3" runp "$WORK/c3.xml" "$WORK/bmix2/sec_tss_sdk_bus_*"

echo "== no bus objects yet =="
no "no bus dir/files fails" runp "$WORK/c3.xml" "$WORK/none/sec_tss_sdk_bus_*"

echo "== missing / malformed config fails (no silent fallback) =="
no "missing config fails" runp "$WORK/nope.xml" "$WORK/b3/sec_tss_sdk_bus_*"
mkcfg "$WORK/craw.xml" "RAW:<config></config>"
no "no tag fails" runp "$WORK/craw.xml" "$WORK/b3/sec_tss_sdk_bus_*"
mkcfg "$WORK/cbad.xml" "RAW:<gamesvr_channel_num_>abc</gamesvr_channel_num_>"
no "non-numeric fails" runp "$WORK/cbad.xml" "$WORK/b3/sec_tss_sdk_bus_*"
mkcfg "$WORK/c0.xml" 0
no "zero is invalid" runp "$WORK/c0.xml" "$WORK/b3/sec_tss_sdk_bus_*"

echo "== whitespace in tag tolerated =="
mkcfg "$WORK/cws.xml" "RAW:<gamesvr_channel_num_>  3  </gamesvr_channel_num_>"
ok "spaces around number parsed" runp "$WORK/cws.xml" "$WORK/b3/sec_tss_sdk_bus_*"

echo "== nested /dev/shm/sec/ layout also counts (original start_game.sh dual check) =="
mkcfg "$WORK/c5.xml" 5
mkbus_nested "$WORK/nested3" 3
ok "nested layout via SECBUS_GLOB_ALT satisfies" \
    env SECAGENT_CONFIG="$WORK/c3.xml" SECBUS_GLOB="$WORK/none/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"
no "nested layout below want fails" \
    env SECAGENT_CONFIG="$WORK/c12.xml" SECBUS_GLOB="$WORK/none/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"
ok "flat + nested combine toward the count" \
    env SECAGENT_CONFIG="$WORK/c5.xml" SECBUS_GLOB="$WORK/b3/sec_tss_sdk_bus_*" \
    SECBUS_GLOB_ALT="$WORK/nested3/tss_sdk_bus_*" bash "$PROBE"

echo "== bus path with spaces + Chinese =="
sp="$WORK/屏 障 中文"
mkbus "$sp" 3
ok "spaced+Chinese bus dir counted" runp "$WORK/c3.xml" "$sp/sec_tss_sdk_bus_*"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
