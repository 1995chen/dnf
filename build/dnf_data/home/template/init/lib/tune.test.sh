#!/bin/bash
# tune.sh 测试脚本

set -u

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
check "MySQL 57 输出 innodb_buffer_pool_size" "$(get_mysql_var innodb_buffer_pool_size nano $((2 * GiB)) 2 57)" 64M

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

echo
echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
