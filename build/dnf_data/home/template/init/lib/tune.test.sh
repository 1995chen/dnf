#!/bin/bash

# shellcheck disable=SC2016

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=common.sh
source "${SCRIPT_PATH}/common.sh"
# shellcheck source=tune.sh
source "${SCRIPT_PATH}/tune.sh"

failed=0
pass=0
check() {
    local desc="$1" got="$2" want="$3"
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-50s got=%q want=%q\n" "$desc" "$got" "$want"
        failed=$((failed + 1))
    fi
}

contains() {
    local desc="$1" haystack="$2" needle="$3"
    case "$haystack" in
    *"$needle"*)
        pass=$((pass + 1))
        ;;
    *)
        printf "FAIL %-50s missing %q\n" "$desc" "$needle"
        failed=$((failed + 1))
        ;;
    esac
}

get_mysql_var() {
    local key="$1" profile="$2" mem="$3" cpus="$4" family="${5:-57}"
    tune_compute_mysql_vars "$profile" "$mem" "$cpus" "$family" |
        awk -F= -v k="$key" '$1 == k {print $2; exit}'
}

GiB=$((1024 * 1024 * 1024))

echo "== tune_classify_profile RAM 阈值 =="
check "2 GiB -> nano" "$(tune_classify_profile $((2 * GiB)))" nano
check "6 GiB -> micro" "$(tune_classify_profile $((6 * GiB)))" micro
check "12 GiB -> small" "$(tune_classify_profile $((12 * GiB)))" small
check "24 GiB -> medium" "$(tune_classify_profile $((24 * GiB)))" medium
check "64 GiB -> large" "$(tune_classify_profile $((64 * GiB)))" large
check "256 GiB -> xlarge" "$(tune_classify_profile $((256 * GiB)))" xlarge

echo "== tune_normalize_profile 别名 =="
check "low -> nano" "$(tune_normalize_profile low)" nano
check "balanced -> medium" "$(tune_normalize_profile balanced)" medium
check "high -> xlarge" "$(tune_normalize_profile high)" xlarge
check "small -> small" "$(tune_normalize_profile small)" small
check "bogus -> empty" "$(tune_normalize_profile bogus)" ""

echo "== tune_size_to_bytes =="
check "64M" "$(tune_size_to_bytes 64M)" "$((64 * 1024 * 1024))"
check "1G" "$(tune_size_to_bytes 1G)" "$((1024 * 1024 * 1024))"
check "100" "$(tune_size_to_bytes 100)" 100
check "garbage" "$(tune_size_to_bytes abc)" 0

echo "== tune_compute_client_pool_size =="
check "nano" "$(tune_compute_client_pool_size nano)" 10
check "xlarge" "$(tune_compute_client_pool_size xlarge)" 1000
check "bogus -> nano default" "$(tune_compute_client_pool_size bogus)" 10

echo "== tune_resolve_profile =="
check "TUNE_PROFILE 优先级高于内存" "$(TUNE_PROFILE=large tune_resolve_profile $((2 * GiB)))" large
check "TUNE_PROFILE low 与 nano 一致" "$(TUNE_PROFILE=low tune_resolve_profile $((64 * GiB)))" nano
check "非法 TUNE_PROFILE 则自动计算性能配置" "$(TUNE_PROFILE=bogus tune_resolve_profile $((24 * GiB)) 2>/dev/null)" medium
check "按内存大小计算性能配置" "$(tune_resolve_profile $((24 * GiB)))" medium
check "若 AUTO_TUNE=false 则使用 nano 配置" "$(AUTO_TUNE=false tune_resolve_profile $((64 * GiB)))" nano
check "若 mem=0 则使用 nano 配置" "$(tune_resolve_profile 0)" nano

echo "== tune_compute_probe_timeout =="
check "nano = 1800" "$(tune_compute_probe_timeout nano)" 1800
check "micro = 900" "$(tune_compute_probe_timeout micro)" 900
check "small = 600" "$(tune_compute_probe_timeout small)" 600
check "medium = 600" "$(tune_compute_probe_timeout medium)" 600
check "large = 600" "$(tune_compute_probe_timeout large)" 600
check "xlarge = 600" "$(tune_compute_probe_timeout xlarge)" 600
check "bogus = 600" "$(tune_compute_probe_timeout bogus)" 600

echo "== tune_is_valid_probe_timeout =="
check "600 ok" "$(tune_is_valid_probe_timeout 600 && echo y || echo n)" y
check "1 ok" "$(tune_is_valid_probe_timeout 1 && echo y || echo n)" y
check "0 rejected" "$(tune_is_valid_probe_timeout 0 && echo y || echo n)" n
check "empty rejected" "$(tune_is_valid_probe_timeout '' && echo y || echo n)" n
check "decimal rejected" "$(tune_is_valid_probe_timeout 1.5 && echo y || echo n)" n
check "garbage rejected" "$(tune_is_valid_probe_timeout abc && echo y || echo n)" n
check "leading zero rejected" "$(tune_is_valid_probe_timeout 0600 && echo y || echo n)" n

echo "== tune_resolve_probe_timeout_ms 单位转换与配置更新 =="
check "nano profile -> 1800000" "$(tune_resolve_probe_timeout_ms nano)" 1800000
check "micro profile -> 900000" "$(tune_resolve_probe_timeout_ms micro)" 900000
check "small profile -> 600000" "$(tune_resolve_probe_timeout_ms small)" 600000
check "PROBE_TIMEOUT 覆盖默认配置" "$(PROBE_TIMEOUT=1200 tune_resolve_probe_timeout_ms nano)" 1200000
check "若 PROBE_TIMEOUT 非法则使用对应性能配置的时间" "$(PROBE_TIMEOUT=abc tune_resolve_probe_timeout_ms nano 2>/dev/null)" 1800000
check "若 PROBE_TIMEOUT=0 则使用对应性能配置的时间" "$(PROBE_TIMEOUT=0 tune_resolve_probe_timeout_ms micro 2>/dev/null)" 900000

echo "== tune_compute_malloc_conf narenas 受 profile cap 限制 =="
# nano cap=2, 128 CPU 应为 2
contains "nano @ 128 cpu narenas=2" "$(tune_compute_malloc_conf nano 128)" "narenas:2,"
# nano 1 CPU 应为 1
contains "nano @ 1 cpu narenas=1" "$(tune_compute_malloc_conf nano 1)" "narenas:1,"
# micro cap=4, 128 CPU 应为 4
contains "micro @ 128 cpu narenas=4" "$(tune_compute_malloc_conf micro 128)" "narenas:4,"
# micro 低于 cap 时不触发最大限制
contains "micro @ 3 cpu narenas=3" "$(tune_compute_malloc_conf micro 3)" "narenas:3,"
# small+ 使用 min(cpu * 2, profile cap)
contains "small @ 4 cpu narenas=8" "$(tune_compute_malloc_conf small 4)" "narenas:8,"
contains "small @ 128 cpu narenas=8" "$(tune_compute_malloc_conf small 128)" "narenas:8,"
contains "medium @ 8 cpu narenas=16" "$(tune_compute_malloc_conf medium 8)" "narenas:16,"
contains "medium @ 128 cpu narenas=16" "$(tune_compute_malloc_conf medium 128)" "narenas:16,"
contains "large @ 16 cpu narenas=32" "$(tune_compute_malloc_conf large 16)" "narenas:32,"
contains "large @ 128 cpu narenas=64" "$(tune_compute_malloc_conf large 128)" "narenas:64,"
contains "xlarge @ 64 cpu narenas=128" "$(tune_compute_malloc_conf xlarge 64)" "narenas:128,"
contains "xlarge @ 128 cpu narenas=256" "$(tune_compute_malloc_conf xlarge 128)" "narenas:256,"
# 未知 profile 退回 nano
contains "bogus -> nano cap" "$(tune_compute_malloc_conf bogus 128)" "narenas:2,"

echo "== tune_compute_malloc_conf arch=64 narenas 倍率与 cap 上限 =="
# nano/micro cap 1x
contains "nano @ 4 cpu arch=64 narenas=2" "$(tune_compute_malloc_conf nano 4 64)" "narenas:2,"
contains "micro @ 8 cpu arch=64 narenas=4" "$(tune_compute_malloc_conf micro 8 64)" "narenas:4,"
# small cap 不变, 但 4x 倍率生效
contains "small @ 1 cpu arch=64 narenas=4" "$(tune_compute_malloc_conf small 1 64)" "narenas:4,"
contains "small @ 4 cpu arch=64 narenas=8" "$(tune_compute_malloc_conf small 4 64)" "narenas:8,"
contains "medium @ 4 cpu arch=64 narenas=16" "$(tune_compute_malloc_conf medium 4 64)" "narenas:16,"
contains "medium @ 8 cpu arch=64 narenas=32" "$(tune_compute_malloc_conf medium 8 64)" "narenas:32,"
contains "medium @ 128 cpu arch=64 narenas=32" "$(tune_compute_malloc_conf medium 128 64)" "narenas:32,"
contains "large @ 8 cpu arch=64 narenas=32" "$(tune_compute_malloc_conf large 8 64)" "narenas:32,"
contains "large @ 16 cpu arch=64 narenas=64" "$(tune_compute_malloc_conf large 16 64)" "narenas:64,"
contains "large @ 32 cpu arch=64 narenas=128" "$(tune_compute_malloc_conf large 32 64)" "narenas:128,"
contains "large @ 128 cpu arch=64 narenas=128" "$(tune_compute_malloc_conf large 128 64)" "narenas:128,"
contains "xlarge @ 32 cpu arch=64 narenas=128" "$(tune_compute_malloc_conf xlarge 32 64)" "narenas:128,"
contains "xlarge @ 64 cpu arch=64 narenas=256" "$(tune_compute_malloc_conf xlarge 64 64)" "narenas:256,"
contains "xlarge @ 128 cpu arch=64 narenas=512" "$(tune_compute_malloc_conf xlarge 128 64)" "narenas:512,"
contains "xlarge @ 256 cpu arch=64 narenas=1024" "$(tune_compute_malloc_conf xlarge 256 64)" "narenas:1024,"
contains "xlarge @ 1024 cpu arch=64 narenas=1024" "$(tune_compute_malloc_conf xlarge 1024 64)" "narenas:1024,"
# 非法 arch 当成 32 位处理
contains "small @ 4 cpu arch=bogus -> 32 cap" "$(tune_compute_malloc_conf small 4 bogus)" "narenas:8,"
contains "medium @ 8 cpu arch=bogus -> 32 cap" "$(tune_compute_malloc_conf medium 8 bogus)" "narenas:16,"

echo "== tune_compute_malloc_conf nano/micro =="
nano_conf=$(tune_compute_malloc_conf nano 2)
contains "nano dirty_decay_ms=1000" "$nano_conf" "dirty_decay_ms:1000"
contains "nano muzzy_decay_ms=500" "$nano_conf" "muzzy_decay_ms:500"
contains "nano lg_tcache_max=13" "$nano_conf" "lg_tcache_max:13"
contains "nano background_thread=false" "$nano_conf" "background_thread:false"
contains "nano retain=false" "$nano_conf" "retain:false"
contains "nano metadata_thp=disabled" "$nano_conf" "metadata_thp:disabled"
contains "nano thp=never" "$nano_conf" "thp:never"

micro_conf=$(tune_compute_malloc_conf micro 2)
contains "micro dirty_decay_ms=3000" "$micro_conf" "dirty_decay_ms:3000"
contains "micro muzzy_decay_ms=1000" "$micro_conf" "muzzy_decay_ms:1000"
contains "micro lg_tcache_max=14" "$micro_conf" "lg_tcache_max:14"
contains "micro background_thread=false" "$micro_conf" "background_thread:false"
contains "micro retain=false" "$micro_conf" "retain:false"
contains "micro metadata_thp=disabled" "$micro_conf" "metadata_thp:disabled"

echo "== tune_compute_malloc_conf small+ =="
small_conf=$(tune_compute_malloc_conf small 4)
contains "small background_thread=true" "$small_conf" "background_thread:true"
contains "small retain=true" "$small_conf" "retain:true"
contains "small thp=never" "$small_conf" "thp:never"

large_conf=$(tune_compute_malloc_conf large 8)
contains "large background_thread=true" "$large_conf" "background_thread:true"
contains "large retain=true" "$large_conf" "retain:true"
contains "large metadata_thp=auto" "$large_conf" "metadata_thp:auto"

echo "== tune_compute_mysql_vars thread_cache_size cap =="
check "nano @ 1 cpu = 8" "$(get_mysql_var thread_cache_size nano $((8 * GiB)) 1)" 8
check "nano @ 128 cpu = 16" "$(get_mysql_var thread_cache_size nano $((8 * GiB)) 128)" 16
check "nano @ 256 cpu = 16" "$(get_mysql_var thread_cache_size nano $((8 * GiB)) 256)" 16
check "micro @ 128 cpu = 32" "$(get_mysql_var thread_cache_size micro $((8 * GiB)) 128)" 32
check "small @ 128 cpu = 64" "$(get_mysql_var thread_cache_size small $((8 * GiB)) 128)" 64
check "medium @ 128 cpu = 128" "$(get_mysql_var thread_cache_size medium $((24 * GiB)) 128)" 128
check "large @ 128 cpu = 256" "$(get_mysql_var thread_cache_size large $((64 * GiB)) 128)" 256
check "xlarge @ 128 cpu = 256" "$(get_mysql_var thread_cache_size xlarge $((256 * GiB)) 128)" 256
check "xlarge @ 512 cpu = 512" "$(get_mysql_var thread_cache_size xlarge $((256 * GiB)) 512)" 512
check "bogus -> nano cap" "$(get_mysql_var thread_cache_size bogus $((8 * GiB)) 128)" 16

echo "== tune_compute_mysql_vars 5.0 vs 5.7 字段名 =="
check "MySQL 50 用 table_cache" "$(get_mysql_var table_cache nano $((2 * GiB)) 2 50)" 128
check "MySQL 57 用 table_open_cache" "$(get_mysql_var table_open_cache nano $((2 * GiB)) 2 57)" 128
check "MySQL 50 不输出 innodb_buffer_pool_size" "$(get_mysql_var innodb_buffer_pool_size nano $((2 * GiB)) 2 50)" ""
check "MySQL 57 nano innodb_buffer_pool_size" "$(get_mysql_var innodb_buffer_pool_size nano $((2 * GiB)) 2 57)" 16M
check "MySQL 57 micro innodb_buffer_pool_size" "$(get_mysql_var innodb_buffer_pool_size micro $((6 * GiB)) 2 57)" 32M
check "MySQL 57 small innodb_buffer_pool_size" "$(get_mysql_var innodb_buffer_pool_size small $((12 * GiB)) 4 57)" 64M

check "MySQL 50 不输出 chunk_size" "$(get_mysql_var innodb_buffer_pool_chunk_size nano $((2 * GiB)) 2 50)" ""
check "MySQL 57 nano chunk_size = pool" "$(get_mysql_var innodb_buffer_pool_chunk_size nano $((2 * GiB)) 2 57)" 16M
check "MySQL 57 micro chunk_size = pool" "$(get_mysql_var innodb_buffer_pool_chunk_size micro $((6 * GiB)) 2 57)" 32M
check "MySQL 57 small chunk_size = pool" "$(get_mysql_var innodb_buffer_pool_chunk_size small $((12 * GiB)) 4 57)" 64M
check "MySQL 57 medium 不输出 chunk_size" "$(get_mysql_var innodb_buffer_pool_chunk_size medium $((24 * GiB)) 8 57)" ""

# 5.7 关闭 query cache，5.0 不变
check "MySQL 50 query_cache_type=1" "$(get_mysql_var query_cache_type nano $((2 * GiB)) 2 50)" 1
check "MySQL 50 query_cache_size" "$(get_mysql_var query_cache_size nano $((2 * GiB)) 2 50)" 8M
check "MySQL 57 query_cache_type=0" "$(get_mysql_var query_cache_type nano $((2 * GiB)) 2 57)" 0
check "MySQL 57 query_cache_size=0" "$(get_mysql_var query_cache_size nano $((2 * GiB)) 2 57)" 0

# innodb_log_buffer_size
check "MySQL 50 不输出 innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size nano $((2 * GiB)) 2 50)" ""
check "MySQL 57 nano innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size nano $((2 * GiB)) 2 57)" 4M
check "MySQL 57 micro innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size micro $((6 * GiB)) 2 57)" 8M
check "MySQL 57 small innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size small $((12 * GiB)) 4 57)" 8M
check "MySQL 57 medium innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size medium $((24 * GiB)) 8 57)" 32M
check "MySQL 57 large innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size large $((64 * GiB)) 16 57)" 48M
check "MySQL 57 xlarge innodb_log_buffer_size" "$(get_mysql_var innodb_log_buffer_size xlarge $((256 * GiB)) 64 57)" 64M

check "sort_buffer large 最大 2M" "$(get_mysql_var sort_buffer_size large $((64 * GiB)) 16 57)" 2M
check "sort_buffer xlarge 最大 2M" "$(get_mysql_var sort_buffer_size xlarge $((256 * GiB)) 64 57)" 2M
check "read_rnd_buffer xlarge 最大 4M" "$(get_mysql_var read_rnd_buffer_size xlarge $((256 * GiB)) 64 57)" 4M

# innodb_buffer_pool medium 8% / large 10% / xlarge 12%
check "innodb_pool medium 8% of 16G" "$(get_mysql_var innodb_buffer_pool_size medium $((16 * GiB)) 8 57)" 1310M
check "innodb_pool large 10% of 64G" "$(get_mysql_var innodb_buffer_pool_size large $((64 * GiB)) 16 57)" 6553M
check "innodb_pool xlarge 12% of 128G" "$(get_mysql_var innodb_buffer_pool_size xlarge $((128 * GiB)) 64 57)" 15728M

check "MySQL 50 不输出 performance_schema" "$(get_mysql_var performance_schema nano $((2 * GiB)) 2 50)" ""
check "MySQL 57 nano 关闭 performance_schema" "$(get_mysql_var performance_schema nano $((2 * GiB)) 2 57)" OFF
check "MySQL 57 low 关闭 performance_schema" "$(get_mysql_var performance_schema "$(tune_normalize_profile low)" $((2 * GiB)) 2 57)" OFF
check "MySQL 57 micro 关闭 performance_schema" "$(get_mysql_var performance_schema micro $((6 * GiB)) 2 57)" OFF
check "MySQL 57 small 关闭 performance_schema" "$(get_mysql_var performance_schema small $((12 * GiB)) 4 57)" OFF
check "MySQL 57 medium 打开 performance_schema" "$(get_mysql_var performance_schema medium $((24 * GiB)) 8 57)" ON
check "MySQL 57 balanced 打开 performance_schema" "$(get_mysql_var performance_schema "$(tune_normalize_profile balanced)" $((24 * GiB)) 8 57)" ON
check "MySQL 57 large 打开 performance_schema" "$(get_mysql_var performance_schema large $((64 * GiB)) 16 57)" ON
check "MySQL 57 xlarge 打开 performance_schema" "$(get_mysql_var performance_schema xlarge $((256 * GiB)) 64 57)" ON

echo "== tune_is_valid_override_value =="
check "128M ok" "$(tune_is_valid_override_value 128M && echo y || echo n)" y
check "1024 ok" "$(tune_is_valid_override_value 1024 && echo y || echo n)" y
check "1MM rejected" "$(tune_is_valid_override_value 1MM && echo y || echo n)" n
check "garbage rejected" "$(tune_is_valid_override_value garbage && echo y || echo n)" n
check "1.5G rejected" "$(tune_is_valid_override_value 1.5G && echo y || echo n)" n
check "empty rejected" "$(tune_is_valid_override_value '' && echo y || echo n)" n

echo "== tune_apply_mysql_overrides version check =="
base57=$(tune_compute_mysql_vars small $((8 * GiB)) 4 57)
base50=$(tune_compute_mysql_vars small $((8 * GiB)) 4 50)

out=$(TUNE_MYSQL_QUERY_CACHE_SIZE=64M tune_apply_mysql_overrides "$base57" 57 2>&1)
contains "MySQL 5.7 跳过 query_cache_size" "$out" "ignored on MySQL >=5.7"

out=$(TUNE_MYSQL_INNODB_BUFFER_POOL_SIZE=512M tune_apply_mysql_overrides "$base57" 57)
contains "MySQL 5.7 接受 innodb_buffer_pool_size" "$out" "innodb_buffer_pool_size=512M"

out=$(TUNE_MYSQL_INNODB_BUFFER_POOL_SIZE=512M tune_apply_mysql_overrides "$base50" 50 2>&1)
contains "MySQL 5.0 跳过 innodb_buffer_pool_size" "$out" "ignored on MySQL 5.0"

out=$(TUNE_MYSQL_TABLE_OPEN_CACHE=999 tune_apply_mysql_overrides "$base50" 50)
contains "MySQL 5.0 将 table_open_cache 改写为 table_cache" "$out" "table_cache=999"

out=$(TUNE_MYSQL_KEY_BUFFER_SIZE=garbage tune_apply_mysql_overrides "$base57" 57 2>&1)
contains "忽略非法值" "$out" "rejected"

echo "== tune_apply_malloc_conf_64 =="
out=$(MALLOC_CONF=orig MALLOC_CONF_64=tuned bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_64
    echo "$MALLOC_CONF"
')
check "手动设置的64位配置应覆盖 MALLOC_CONF" "$out" "tuned"

out=$(MALLOC_CONF=orig MALLOC_CONF_64='' bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_64
    echo "[${MALLOC_CONF}]"
')
check "传入空配置时，MALLOC_CONF也覆盖为空" "$out" "[]"

out=$(MALLOC_CONF=orig bash -c '
    unset MALLOC_CONF_64
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_64
    echo "$MALLOC_CONF"
')
check "未设置64位配置时，MALLOC_CONF 保持不变" "$out" "orig"

echo "== tune_resolve_and_export 会导出 MALLOC_CONF_64 =="
out=$(env -u MALLOC_CONF -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "MC=$MALLOC_CONF"
    echo "M64=$MALLOC_CONF_64"
')
contains "32 位自动计算使用 2x 倍率" "$out" "MC=narenas:"
contains "64 位自动计算使用 4x 倍率" "$out" "M64=narenas:"

out=$(env -u MALLOC_CONF MALLOC_CONF_64=keepme TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_64"
')
check "手动设置的 MALLOC_CONF_64 不被覆盖" "$out" "keepme"

out=$(env -u MALLOC_CONF MALLOC_CONF_64='' TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "[${MALLOC_CONF_64}]"
')
check "清空 MALLOC_CONF_64 后保持为空" "$out" "[]"

echo "== tune_apply_malloc_conf_32 =="
out=$(MALLOC_CONF=tuned MALLOC_CONF_32=base bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_32
    echo "$MALLOC_CONF"
')
check "手动设置的32位配置应覆盖 MALLOC_CONF" "$out" "base"

out=$(MALLOC_CONF=tuned MALLOC_CONF_32='' bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_32
    echo "[${MALLOC_CONF}]"
')
check "传入空配置时，MALLOC_CONF 也应该为空" "$out" "[]"

out=$(MALLOC_CONF=tuned bash -c '
    unset MALLOC_CONF_32
    source '"$SCRIPT_PATH"'/tune.sh
    tune_apply_malloc_conf_32
    echo "$MALLOC_CONF"
')
check "未设置32位配置时 MALLOC_CONF 保持不变" "$out" "tuned"

echo "== tune_resolve_and_export 会导出 MALLOC_CONF_32 =="
out=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "M32=$MALLOC_CONF_32"
    echo "MC=$MALLOC_CONF"
')
contains "auto MALLOC_CONF_32 不为空" "$out" "M32=narenas:"
out32=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF"
')
out_m32=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_32"
')
check "MALLOC_CONF 默认等于 MALLOC_CONF_32" "$out32" "$out_m32"

out=$(env -u MALLOC_CONF MALLOC_CONF_32=keepme TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_32"
')
check "手动设置的 MALLOC_CONF_32 不被覆盖" "$out" "keepme"

out=$(env -u MALLOC_CONF MALLOC_CONF_32='' TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "[${MALLOC_CONF_32}]"
')
check "清空 MALLOC_CONF_32 后保持为空" "$out" "[]"

echo "== 32 位 与 64 位配置切换 =="
# 先切到 64 位, 再切回 32 位
out=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    base="$MALLOC_CONF"
    tune_apply_malloc_conf_64
    [ "$MALLOC_CONF" = "$MALLOC_CONF_64" ] || echo "step1 mismatch"
    tune_apply_malloc_conf_32
    [ "$MALLOC_CONF" = "$base" ] && echo ok || echo "step2 mismatch"
')
check "64->32 切换正常" "$out" "ok"

out=$(env -u MALLOC_CONF_32 -u MALLOC_CONF_64 MALLOC_CONF=custom-marker TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    base="$MALLOC_CONF"
    tune_apply_malloc_conf_64
    [ "$MALLOC_CONF" = "$MALLOC_CONF_64" ] || echo "step1 mismatch"
    tune_apply_malloc_conf_32
    [ "$MALLOC_CONF" = "$base" ] && echo ok || echo "step2 mismatch: got [$MALLOC_CONF] want [$base]"
')
check "64位切换为32位" "$out" "ok"

out=$(env -u MALLOC_CONF_32 -u MALLOC_CONF_64 MALLOC_CONF=custom-marker TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_32"
')
check "未设置 MALLOC_CONF_32 时，MALLOC_CONF_32 使用手动设置的 MALLOC_CONF" "$out" "custom-marker"

out=$(env -u MALLOC_CONF_32 -u MALLOC_CONF_64 MALLOC_CONF=global-X TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_64"
')
check "未设置 MALLOC_CONF_64 时，MALLOC_CONF_64 使用手动设置的 MALLOC_CONF" "$out" "global-X"

# 同时设 MALLOC_CONF 与 MALLOC_CONF_64, 64位应用使用 MALLOC_CONF_64
out=$(env -u MALLOC_CONF_32 MALLOC_CONF=global-X MALLOC_CONF_64=granular-Y TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "$MALLOC_CONF_64"
')
check "MALLOC_CONF_64 优先级高于 MALLOC_CONF" "$out" "granular-Y"

# 同时设 MALLOC_CONF 与 MALLOC_CONF_32, _32 使用自己的配置, _64 使用 MALLOC_CONF
out=$(env -u MALLOC_CONF_64 MALLOC_CONF=global-X MALLOC_CONF_32=granular-A TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    echo "32=$MALLOC_CONF_32"
    echo "64=$MALLOC_CONF_64"
')
contains "MALLOC_CONF_32 优先级高于 MALLOC_CONF" "$out" "32=granular-A"
contains "MALLOC_CONF_64 使用 MALLOC_CONF" "$out" "64=global-X"

# 只设置 MALLOC_CONF, 64 位切换后值不变
out=$(env -u MALLOC_CONF_32 -u MALLOC_CONF_64 MALLOC_CONF=global-X TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    tune_apply_malloc_conf_64
    echo "$MALLOC_CONF"
')
check "手动设置的 MALLOC_CONF 经过 64 位切换后值不变" "$out" "global-X"

out=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    [ "$MALLOC_CONF_32" != "$MALLOC_CONF_64" ] && echo ok || echo "equal: 32=[$MALLOC_CONF_32] 64=[$MALLOC_CONF_64]"
')
check "自动计算时 32 位与 64 位配置不同" "$out" "ok"

echo "== 各种配置的组合情况 =="
resolve_case() {
    env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 TUNE_PROFILE=large bash -c "
        $1
        source '$SCRIPT_PATH/tune.sh'
        tune_resolve_and_export \"no\" >/dev/null
        printf 'MC=%s|M32=%s|M64=%s\n' \"\$MALLOC_CONF\" \"\$MALLOC_CONF_32\" \"\$MALLOC_CONF_64\"
    "
}

extract_mc() { echo "$1" | sed -n 's/^MC=\([^|]*\)|.*/\1/p'; }
extract_m32() { echo "$1" | sed -n 's/.*|M32=\([^|]*\)|.*/\1/p'; }
extract_m64() { echo "$1" | sed -n 's/.*|M64=\(.*\)$/\1/p'; }

# 只设 MALLOC_CONF -> MC=X M32=X M64=X
out=$(resolve_case 'export MALLOC_CONF=X')
check "case1 MC=X" "$(extract_mc "$out")" "X"
check "case1 M32=X" "$(extract_m32 "$out")" "X"
check "case1 M64=X" "$(extract_m64 "$out")" "X"

# MC + _32 -> MC=X M32=A M64=X
out=$(resolve_case 'export MALLOC_CONF=X MALLOC_CONF_32=A')
check "case2 MC=X" "$(extract_mc "$out")" "X"
check "case2 M32=A" "$(extract_m32 "$out")" "A"
check "case2 M64=X" "$(extract_m64 "$out")" "X"

# MC + _64 -> MC=X M32=X M64=B
out=$(resolve_case 'export MALLOC_CONF=X MALLOC_CONF_64=B')
check "case3 MC=X" "$(extract_mc "$out")" "X"
check "case3 M32=X" "$(extract_m32 "$out")" "X"
check "case3 M64=B" "$(extract_m64 "$out")" "B"

# 只设 _32 -> MC=A M32=A M64=auto-64
out=$(resolve_case 'export MALLOC_CONF_32=A')
check "case4 MC=A" "$(extract_mc "$out")" "A"
check "case4 M32=A" "$(extract_m32 "$out")" "A"
out_m64=$(extract_m64 "$out")
case "$out_m64" in narenas:*) check "case4 M64 自动计算" ok ok ;; *) check "case4 M64 自动计算" "$out_m64" "narenas:..." ;; esac

# 只设 _64 -> MC=auto-32 M32=auto-32 M64=B
out=$(resolve_case 'export MALLOC_CONF_64=B')
out_mc=$(extract_mc "$out")
out_m32=$(extract_m32 "$out")
case "$out_mc" in narenas:*) check "case5 MC 自动计算" ok ok ;; *) check "case5 MC 自动计算" "$out_mc" "narenas:..." ;; esac
case "$out_m32" in narenas:*) check "case5 M32 自动计算" ok ok ;; *) check "case5 M32 自动计算" "$out_m32" "narenas:..." ;; esac
check "case5 MC == M32" "$out_mc" "$out_m32"
check "case5 M64=B" "$(extract_m64 "$out")" "B"

# 都不设 -> MC=auto-32 M32=auto-32 M64=auto-64
out=$(resolve_case '')
out_mc=$(extract_mc "$out")
out_m32=$(extract_m32 "$out")
out_m64=$(extract_m64 "$out")
case "$out_mc" in narenas:*) check "case6 MC 自动计算" ok ok ;; *) check "case6 MC 自动计算" "$out_mc" "narenas:..." ;; esac
case "$out_m32" in narenas:*) check "case6 M32 自动计算" ok ok ;; *) check "case6 M32 自动计算" "$out_m32" "narenas:..." ;; esac
case "$out_m64" in narenas:*) check "case6 M64 自动计算" ok ok ;; *) check "case6 M64 自动计算" "$out_m64" "narenas:..." ;; esac
check "case6 MC == M32" "$out_mc" "$out_m32"
if [ "$out_mc" != "$out_m64" ]; then
    check "case6 MC 与 M64 不同" ok ok
else
    check "case6 MC 与 M64 不同" "same" "different"
fi

# 都设置 -> MC=X M32=A M64=B
out=$(resolve_case 'export MALLOC_CONF=X MALLOC_CONF_32=A MALLOC_CONF_64=B')
check "case7 MC=X" "$(extract_mc "$out")" "X"
check "case7 M32=A" "$(extract_m32 "$out")" "A"
check "case7 M64=B" "$(extract_m64 "$out")" "B"

# 设置空 MALLOC_CONF 的情况下，MC M32 和 M64 都为空
out=$(resolve_case "export MALLOC_CONF=''")
check "case8 MC 为空" "$(extract_mc "$out")" ""
check "case8 M32 为空" "$(extract_m32 "$out")" ""
check "case8 M64 为空" "$(extract_m64 "$out")" ""

# 设置空 MALLOC_CONF 但还设置了非空的32位或64位配置
out=$(resolve_case "export MALLOC_CONF='' MALLOC_CONF_32=A MALLOC_CONF_64=B")
check "case9 MC 为空" "$(extract_mc "$out")" ""
check "case9 M32 使用手动设置的值" "$(extract_m32 "$out")" "A"
check "case9 M64 使用手动设置的值" "$(extract_m64 "$out")" "B"

echo "== 架构切换后使用新配置 =="
# 32 位程序: apply_32 后 MALLOC_CONF == MALLOC_CONF_32
out=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 \
    MALLOC_CONF=X MALLOC_CONF_32=A MALLOC_CONF_64=B TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    tune_apply_malloc_conf_32
    echo "$MALLOC_CONF"
')
check "切换为32位后 MC == M32" "$out" "A"

# 64 位程序: apply_64 后 MALLOC_CONF == MALLOC_CONF_64
out=$(env -u MALLOC_CONF -u MALLOC_CONF_32 -u MALLOC_CONF_64 \
    MALLOC_CONF=X MALLOC_CONF_32=A MALLOC_CONF_64=B TUNE_PROFILE=large bash -c '
    source '"$SCRIPT_PATH"'/tune.sh
    tune_resolve_and_export "no" >/dev/null
    tune_apply_malloc_conf_64
    echo "$MALLOC_CONF"
')
check "切换为64位后 MC == M64" "$out" "B"

echo "== tune_detect_mysql_family 获取 mysql 版本时忽略配置文件 =="
# 不带 --no-defaults 时模拟 mysql 5.0 读 my.cnf 因 !includedir 目录不存在而崩溃
fam_dir=$(mktemp -d)
cat >"$fam_dir/mysqld" <<'STUB'
#!/bin/bash
nd=0
for a in "$@"; do
    [ "$a" = "--no-defaults" ] && nd=1
done
if [ "$nd" = 0 ]; then
    echo "mysqld: Can't read dir of '/data/my.cnf.d' (Errcode: 2)" >&2
    echo "Fatal error in defaults handling. Program aborted" >&2
    exit 1
fi
echo "mysqld  Ver 5.0.95-community for unknown-linux-gnu on x86_64"
exit 0
STUB
chmod +x "$fam_dir/mysqld"
check "mysql 5.0 获取版本时不受 my.cnf 影响" \
    "$(MYSQLD_BIN="$fam_dir/mysqld" tune_detect_mysql_family)" "50"
rm -rf "$fam_dir"

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
