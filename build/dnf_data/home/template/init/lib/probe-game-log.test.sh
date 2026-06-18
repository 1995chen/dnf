#!/bin/bash
# probe-game-log.sh 测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROBE="${SCRIPT_PATH}/probe-game-log.sh"

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

write_ready_log() {
    local f="$1"
    {
        echo "GeoIP Allow Country Code : CN"
        echo "GeoIP Allow Country Code : HK"
        echo "GeoIP Allow Country Code : KR"
        echo "GeoIP Allow Country Code : MO"
        echo "GeoIP Allow Country Code : TW"
        echo "[!] Connect To Monitor Server"
        echo "[!] Monitor Server Connected"
        echo "[!] Connect To Guild Server"
        echo "[!] Guild Server Connected"
    } >"$f"
}

run() { GAME_PROC_START_EPOCH=1 bash "$PROBE" "$@"; }
run_ps() {
    local ps="$1"
    shift
    GAME_PROC_START_EPOCH="$ps" bash "$PROBE" "$@"
}

echo "== 日志目录或文件缺失: 未就绪 =="
no "频道日志目录不存在" run siroco11 "$WORK/none"
mkdir -p "$WORK/log/siroco11"
no "无 Log*.init 文件" run siroco11 "$WORK/log"

echo "== 日志为空或关键标记不完整: 未就绪 =="
: >"$WORK/log/siroco11/Log20260101.init"
no "日志文件为空" run siroco11 "$WORK/log"
echo "GeoIP Allow Country Code : CN" >"$WORK/log/siroco11/Log20260101.init"
no "五国日志不完整" run siroco11 "$WORK/log"

echo "== 五国日志完整: 就绪 =="
write_ready_log "$WORK/log/siroco11/Log20260101.init"
ok "五国日志完整" run siroco11 "$WORK/log"

# write_ready_log "$WORK/log/siroco11/Log20260101.init"
# sed -i '/Guild Server Connected/d' "$WORK/log/siroco11/Log20260101.init"
# no "Guild 日志不完整" run siroco11 "$WORK/log"
# write_ready_log "$WORK/log/siroco11/Log20260101.init"
# sed -i 's/\[!\] Monitor Server Connected/! Monitor Server Connected/' "$WORK/log/siroco11/Log20260101.init"
# no "Monitor 日志缺少 [!]" run siroco11 "$WORK/log"

echo "== 日志生成时间不早于进程启动时间: 排除上一轮残留 =="
write_ready_log "$WORK/log/siroco11/Log20260101.init"
touch -d '2026-03-01 12:00:00' "$WORK/log/siroco11/Log20260101.init"
lm=$(stat -c %Y "$WORK/log/siroco11/Log20260101.init")
ok "日志比进程启动晚 100 秒, 算本轮产生" run_ps "$((lm - 100))" siroco11 "$WORK/log"
ok "日志比进程启动晚 1 秒, 算本轮产生" run_ps "$((lm - 1))" siroco11 "$WORK/log"
ok "日志与进程同一秒启动, 算本轮产生" run_ps "$lm" siroco11 "$WORK/log"
no "日志比进程启动早 1 秒, 上一轮残留" run_ps "$((lm + 1))" siroco11 "$WORK/log"
no "日志比进程启动早 100 秒, 上一轮残留" run_ps "$((lm + 100))" siroco11 "$WORK/log"

echo "== df_game 进程不存在: 未就绪 =="
mkdir -p "$WORK/log/siroco99"
write_ready_log "$WORK/log/siroco99/Log20260101.init"
no "无 df_game 进程" env -u GAME_PROC_START_EPOCH bash "$PROBE" siroco99 "$WORK/log"

echo "== 只分析最新日志内容，若其标记不完整则未就绪 =="
mkdir -p "$WORK/log/siroco52"
write_ready_log "$WORK/log/siroco52/Log20260101.init"
sleep 1
echo "partial" >"$WORK/log/siroco52/Log20260102.init"
no "最新日志标记不完整" run siroco52 "$WORK/log"

echo "== 参数错误: 未就绪 =="
no "缺少频道名参数" run
no "频道名含非法字符" run "a-b" "$WORK/log"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
