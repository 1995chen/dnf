#!/bin/bash

tune_normalize_profile() {
    case "$1" in
    low) echo nano ;;
    balanced) echo medium ;;
    high) echo xlarge ;;
    nano | micro | small | medium | large | xlarge) echo "$1" ;;
    *) echo "" ;;
    esac
}

tune_detect_cgroup_version() {
    if [ -f /sys/fs/cgroup/cgroup.controllers ] && [ -r /sys/fs/cgroup/memory.max ]; then
        echo v2
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        echo v1
    else
        echo none
    fi
}

# 检测容器内存限制，未限制时返回全部物理内存
tune_detect_mem_bytes() {
    local raw host
    host=$(awk '/^MemTotal:/ {printf "%d", $2 * 1024}' /proc/meminfo 2>/dev/null)
    [ -z "$host" ] && host=0

    case "$(tune_detect_cgroup_version)" in
    v2)
        raw=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
        if [ "$raw" = "max" ] || [ -z "$raw" ]; then
            echo "$host"
            return 0
        fi
        ;;
    v1)
        raw=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        ;;
    *)
        echo "$host"
        return 0
        ;;
    esac

    if [ -z "$raw" ] || ! [ "$raw" -gt 0 ] 2>/dev/null; then
        echo "$host"
        return 0
    fi

    if [ "$host" -gt 0 ] && [ "$raw" -gt "$host" ] 2>/dev/null; then
        echo "$host"
        return 0
    fi
    echo "$raw"
    return 0
}

tune_detect_cpu_count() {
    local q p
    case "$(tune_detect_cgroup_version)" in
    v2)
        if [ -r /sys/fs/cgroup/cpu.max ]; then
            read -r q p </sys/fs/cgroup/cpu.max
            if [ -n "$q" ] && [ "$q" != "max" ] && [ "${p:-0}" -gt 0 ] 2>/dev/null; then
                echo $(((q + p - 1) / p))
                return 0
            fi
        fi
        ;;
    v1)
        q=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null)
        p=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null)
        if [ "${q:-0}" -gt 0 ] 2>/dev/null && [ "${p:-0}" -gt 0 ] 2>/dev/null; then
            echo $(((q + p - 1) / p))
            return 0
        fi
        ;;
    esac
    nproc 2>/dev/null || echo 1
    return 0
}

# 按 RAM 大小分类
# 4G / 8G / 16G / 32G / 128G。
tune_classify_profile() {
    local bytes="${1:-0}"
    if [ "$bytes" -lt 4294967296 ]; then
        echo nano
    elif [ "$bytes" -lt 8589934592 ]; then
        echo micro
    elif [ "$bytes" -lt 17179869184 ]; then
        echo small
    elif [ "$bytes" -lt 34359738368 ]; then
        echo medium
    elif [ "$bytes" -lt 137438953472 ]; then
        echo large
    else
        echo xlarge
    fi
}

tune_size_to_bytes() {
    local s="${1:-0}"
    local n="${s%[KkMmGgTt]}"
    case "$n" in
    '' | *[!0-9]*)
        echo 0
        return 0
        ;;
    esac
    case "$s" in
    *K | *k) echo $((n * 1024)) ;;
    *M | *m) echo $((n * 1024 * 1024)) ;;
    *G | *g) echo $((n * 1024 * 1024 * 1024)) ;;
    *T | *t) echo $((n * 1024 * 1024 * 1024 * 1024)) ;;
    *) echo "$n" ;;
    esac
}

tune_compute_malloc_conf() {
    local profile="$1" cpus="${2:-1}"
    local narenas_cap lg_tcache dirty muzzy
    case "$profile" in
    nano)
        narenas_cap=2
        lg_tcache=13
        dirty=1000
        muzzy=0
        ;;
    micro)
        narenas_cap=2
        lg_tcache=14
        dirty=5000
        muzzy=1000
        ;;
    small)
        narenas_cap=4
        lg_tcache=15
        dirty=10000
        muzzy=5000
        ;;
    medium)
        narenas_cap=4
        lg_tcache=16
        dirty=20000
        muzzy=10000
        ;;
    large)
        narenas_cap=8
        lg_tcache=17
        dirty=30000
        muzzy=30000
        ;;
    xlarge)
        narenas_cap=16
        lg_tcache=18
        dirty=60000
        muzzy=60000
        ;;
    *)
        narenas_cap=2
        lg_tcache=13
        dirty=1000
        muzzy=0
        ;;
    esac

    local narenas=$cpus
    [ "$narenas" -gt "$narenas_cap" ] && narenas=$narenas_cap
    [ "$narenas" -lt 1 ] && narenas=1

    local parts="narenas:${narenas}"
    parts="${parts},lg_tcache_max:${lg_tcache}"
    parts="${parts},dirty_decay_ms:${dirty}"
    parts="${parts},muzzy_decay_ms:${muzzy}"
    parts="${parts},background_thread:true"
    case "$profile" in
    nano | micro | small | medium) parts="${parts},thp:never" ;;
    large | xlarge) parts="${parts},metadata_thp:auto" ;;
    esac
    echo "$parts"
}

tune_compute_client_pool_size() {
    case "$1" in
    nano) echo 10 ;;
    micro) echo 30 ;;
    small) echo 100 ;;
    medium) echo 300 ;;
    large) echo 600 ;;
    xlarge) echo 1000 ;;
    *) echo 10 ;;
    esac
}

tune_detect_mysql_family() {
    local bin out
    for bin in /usr/local/mysql/bin/mysqld /usr/sbin/mysqld /usr/bin/mysqld; do
        if [ -x "$bin" ]; then
            out=$("$bin" --version 2>/dev/null || true)
            case "$out" in
            *"Ver 5.0."*)
                echo 50
                return 0
                ;;
            *"Ver 5.7."*)
                echo 57
                return 0
                ;;
            *"Ver 8."*)
                echo 57
                return 0
                ;;
            esac
        fi
    done
    echo 57
    return 0
}

tune_compute_mysql_vars() {
    local profile="$1" mem="${2:-0}" cpus="${3:-1}" family="${4:-57}"
    local key_buf tos sb rb rrb msb tcs mac map qcs ibps_spec
    case "$profile" in
    nano)
        key_buf=64M
        tos=128
        sb=512K
        rb=512K
        rrb=1M
        msb=16M
        tcs=8
        mac=4096
        map=1M
        qcs=8M
        ibps_spec=64M
        ;;
    micro)
        key_buf=96M
        tos=256
        sb=1M
        rb=512K
        rrb=2M
        msb=32M
        tcs=16
        mac=4096
        map=4M
        qcs=16M
        ibps_spec=128M
        ;;
    small)
        key_buf=128M
        tos=512
        sb=1M
        rb=1M
        rrb=2M
        msb=32M
        tcs=32
        mac=4096
        map=16M
        qcs=32M
        ibps_spec=256M
        ;;
    medium)
        key_buf=192M
        tos=1024
        sb=2M
        rb=1M
        rrb=4M
        msb=64M
        tcs=64
        mac=4096
        map=32M
        qcs=64M
        ibps_spec=8%
        ;;
    large)
        key_buf=256M
        tos=1536
        sb=4M
        rb=2M
        rrb=4M
        msb=64M
        tcs=128
        mac=4096
        map=64M
        qcs=128M
        ibps_spec=10%
        ;;
    xlarge)
        key_buf=384M
        tos=2048
        sb=4M
        rb=2M
        rrb=8M
        msb=128M
        tcs=256
        mac=4096
        map=64M
        qcs=128M
        ibps_spec=12%
        ;;
    *)
        key_buf=64M
        tos=128
        sb=512K
        rb=512K
        rrb=1M
        msb=16M
        tcs=8
        mac=4096
        map=1M
        qcs=8M
        ibps_spec=64M
        ;;
    esac

    local tcs_floor=$((cpus * 2))
    [ "$tcs_floor" -gt "$tcs" ] && tcs=$tcs_floor

    echo "key_buffer_size=$key_buf"
    if [ "$family" = "50" ]; then
        echo "table_cache=$tos"
    else
        echo "table_open_cache=$tos"
    fi
    echo "sort_buffer_size=$sb"
    echo "read_buffer_size=$rb"
    echo "read_rnd_buffer_size=$rrb"
    echo "myisam_sort_buffer_size=$msb"
    echo "thread_cache_size=$tcs"
    echo "max_connections=$mac"
    echo "max_allowed_packet=$map"

    if [ "$family" = "50" ]; then
        echo "query_cache_type=1"
        echo "query_cache_size=$qcs"
        return 0
    fi

    # MySQL 5.7+ 的 innodb_buffer_pool_size 取百分比或固定值
    local ibps_value
    case "$ibps_spec" in
    *%)
        local pct="${ibps_spec%\%}"
        local pool_bytes=$((mem * pct / 100))
        local pool_mb=$((pool_bytes / 1048576))
        [ "$pool_mb" -lt 64 ] && pool_mb=64
        ibps_value="${pool_mb}M"
        ;;
    *)
        ibps_value="$ibps_spec"
        ;;
    esac
    echo "innodb_buffer_pool_size=$ibps_value"

    # pool > 1G 时按性能配置和 CPU 数设置 innodb_buffer_pool_instances
    local pool_bytes
    pool_bytes=$(tune_size_to_bytes "$ibps_value")
    if [ "$pool_bytes" -gt 1073741824 ] 2>/dev/null; then
        local ibpi=$cpus ibpi_cap
        case "$profile" in
        small) ibpi_cap=4 ;;
        medium) ibpi_cap=8 ;;
        large | xlarge) ibpi_cap=16 ;;
        *) ibpi_cap=1 ;;
        esac
        [ "$ibpi" -gt "$ibpi_cap" ] && ibpi=$ibpi_cap
        [ "$ibpi" -lt 1 ] && ibpi=1
        if [ "$ibpi" -gt 1 ]; then
            echo "innodb_buffer_pool_instances=$ibpi"
        fi
    fi
    return 0
}

# 校验mysql参数，允许整数或带 K/M/G/T 后缀的整数
tune_is_valid_override_value() {
    [[ "$1" =~ ^[0-9]+[KkMmGgTt]?$ ]]
}

# 使用 TUNE_MYSQL_* 覆盖自动生成的参数。
#
# MySQL 5.0 TUNE_MYSQL_TABLE_OPEN_CACHE 对应 table_cache
# MySQL 5.7 跳过 TUNE_MYSQL_QUERY_CACHE_SIZE
# MySQL 5.0 跳过 TUNE_MYSQL_INNODB_BUFFER_POOL_SIZE
tune_apply_mysql_overrides() {
    local decl="$1" family="${2:-57}"
    local overrides="\
TUNE_MYSQL_KEY_BUFFER_SIZE:key_buffer_size
TUNE_MYSQL_TABLE_OPEN_CACHE:table_open_cache
TUNE_MYSQL_SORT_BUFFER_SIZE:sort_buffer_size
TUNE_MYSQL_READ_BUFFER_SIZE:read_buffer_size
TUNE_MYSQL_READ_RND_BUFFER_SIZE:read_rnd_buffer_size
TUNE_MYSQL_THREAD_CACHE_SIZE:thread_cache_size
TUNE_MYSQL_MAX_CONNECTIONS:max_connections
TUNE_MYSQL_MAX_ALLOWED_PACKET:max_allowed_packet
TUNE_MYSQL_QUERY_CACHE_SIZE:query_cache_size
TUNE_MYSQL_INNODB_BUFFER_POOL_SIZE:innodb_buffer_pool_size"

    local env_name key val
    while IFS=: read -r env_name key; do
        [ -z "$env_name" ] && continue
        val="${!env_name:-}"
        [ -z "$val" ] && continue
        # 跳过与当前 MySQL 版本不兼容的参数。
        if [ "$key" = "query_cache_size" ] && [ "$family" != "50" ]; then
            echo "tune: $env_name ignored on MySQL >=5.7 (query_cache_size removed)" >&2
            continue
        fi
        if [ "$key" = "innodb_buffer_pool_size" ] && [ "$family" = "50" ]; then
            echo "tune: $env_name ignored on MySQL 5.0 (InnoDB not default)" >&2
            continue
        fi
        if ! tune_is_valid_override_value "$val"; then
            echo "tune: $env_name='$val' rejected, expect integer or N[KMGT]" >&2
            continue
        fi
        # 把 table_open_cache 改写为 5.0 的写法。
        if [ "$key" = "table_open_cache" ] && [ "$family" = "50" ]; then
            key="table_cache"
        fi
        if echo "$decl" | grep -q "^${key}="; then
            # shellcheck disable=SC2001
            decl=$(echo "$decl" | sed "s|^${key}=.*|${key}=${val}|")
        else
            decl="${decl}
${key}=${val}"
        fi
    done <<EOF
$overrides
EOF
    echo "$decl"
}

tune_apply_mysql_cnf() {
    local cnf="$1"
    local decl="$2"

    if [ ! -f "$cnf" ]; then
        echo "tune: my.cnf not found at $cnf, skip rewrite" >&2
        return 0
    fi

    local tmp
    tmp=$(mktemp 2>/dev/null) || tmp="/tmp/tune-mycnf.$$"
    awk -v decl="$decl" '
        BEGIN {
            n = split(decl, lines, "\n")
            for (i = 1; i <= n; i++) {
                if (lines[i] ~ /=/) {
                    eq = index(lines[i], "=")
                    k = substr(lines[i], 1, eq - 1)
                    v = substr(lines[i], eq + 1)
                    want[k] = v
                    order[++m] = k
                }
            }
        }
        function emit_pending(   i, k) {
            for (i = 1; i <= m; i++) {
                k = order[i]
                if (!(k in seen)) {
                    print k " = " want[k]
                    seen[k] = 1
                }
            }
        }
        /^[[:space:]]*\[/ {
            if (in_mysqld) { emit_pending(); in_mysqld = 0 }
            if ($0 ~ /^[[:space:]]*\[mysqld\][[:space:]]*$/) { in_mysqld = 1; saw_mysqld = 1 }
            print
            next
        }
        in_mysqld && /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=/ {
            key = $0
            sub(/[[:space:]]*=.*/, "", key)
            sub(/^[[:space:]]+/, "", key)
            if (key in want) {
                print key " = " want[key]
                seen[key] = 1
                next
            }
        }
        { print }
        END {
            if (in_mysqld) emit_pending()
            else if (!saw_mysqld && m > 0) {
                print "tune: no [mysqld] section in my.cnf, skipped " m " keys" > "/dev/stderr"
            }
        }
    ' "$cnf" >"$tmp" && mv "$tmp" "$cnf"
}

tune_resolve_and_export() {
    local apply_mysql="${1:-no}"

    if [ -n "${TUNE_PROFILE:-}" ]; then
        local norm
        norm=$(tune_normalize_profile "$TUNE_PROFILE")
        if [ -z "$norm" ]; then
            echo "tune: invalid TUNE_PROFILE='$TUNE_PROFILE', falling back to auto-detect" >&2
            TUNE_PROFILE=""
        else
            TUNE_PROFILE="$norm"
        fi
    fi

    local cg cpus mem
    cg=$(tune_detect_cgroup_version)
    cpus=$(tune_detect_cpu_count)
    [ -z "$cpus" ] || ! [ "$cpus" -gt 0 ] 2>/dev/null && cpus=1
    mem=$(tune_detect_mem_bytes)
    [ -z "$mem" ] || ! [ "$mem" -ge 0 ] 2>/dev/null && mem=0

    local profile profile_src
    if [ -n "${TUNE_PROFILE:-}" ]; then
        profile="$TUNE_PROFILE"
        profile_src="TUNE_PROFILE=$TUNE_PROFILE"
    elif [ "${AUTO_TUNE:-true}" = "true" ] && [ "$mem" -gt 0 ]; then
        profile=$(tune_classify_profile "$mem")
        profile_src="auto (cgroup=$cg)"
    else
        profile=nano
        profile_src="fallback to nano"
    fi

    local malloc_src
    if [ "${MALLOC_CONF+set}" = "set" ]; then
        export MALLOC_CONF
        if [ -z "$MALLOC_CONF" ]; then
            malloc_src="user-cleared"
        else
            malloc_src="user-set"
        fi
    else
        MALLOC_CONF=$(tune_compute_malloc_conf "$profile" "$cpus")
        export MALLOC_CONF
        malloc_src="profile=$profile"
    fi

    local cps_src
    if [ "${CLIENT_POOL_SIZE+set}" = "set" ]; then
        export CLIENT_POOL_SIZE
        if [ -z "$CLIENT_POOL_SIZE" ]; then
            cps_src="user-cleared"
        else
            cps_src="user-set"
        fi
    else
        CLIENT_POOL_SIZE=$(tune_compute_client_pool_size "$profile")
        export CLIENT_POOL_SIZE
        cps_src="profile=$profile"
    fi

    # 更新 my.cnf
    local family decl
    if [ "$apply_mysql" = "yes" ]; then
        family=$(tune_detect_mysql_family)
        decl=$(tune_compute_mysql_vars "$profile" "$mem" "$cpus" "$family")
        decl=$(tune_apply_mysql_overrides "$decl" "$family")
        tune_apply_mysql_cnf /etc/my.cnf "$decl"
    fi

    local mem_mib=$((mem / 1048576))
    local malloc_show="${MALLOC_CONF:-(jemalloc defaults)}"
    echo "[tune] profile=$profile ($profile_src) cpu=$cpus mem=${mem_mib}MiB CLIENT_POOL_SIZE=$CLIENT_POOL_SIZE ($cps_src) MALLOC_CONF=$malloc_show ($malloc_src)"

    if [ "${TUNE_VERBOSE:-false}" = "true" ]; then
        echo "[tune-verbose] cgroup=$cg mem_bytes=$mem cpus=$cpus"
        echo "[tune-verbose] MALLOC_CONF=$MALLOC_CONF"
        if [ "$apply_mysql" = "yes" ]; then
            echo "[tune-verbose] mysql_family=$family"
            # shellcheck disable=SC2001
            echo "$decl" | sed 's/^/[tune-verbose]   /'
        fi
    fi
    return 0
}
