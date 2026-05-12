#!/bin/bash

# 去除变量中的单双引号
# 用法: strip_quotes VAR1 VAR2 VAR3 ...
strip_quotes() {
    local var_name
    for var_name in "$@"; do
        local val="${!var_name}"
        val="${val//\'/}"
        val="${val//\"/}"
        export "$var_name=$val"
    done
}

# 等待TCP端口成功监听
# 用法: wait_for_port HOST PORT [MAX_RETRIES]
# 返回: 0=成功, 1=超时
wait_for_port() {
    local host="$1" port="$2" max_retries="${3:-30}"
    local counter=0
    while [ "$counter" -lt "$max_retries" ]; do
        if socat -T2 /dev/null "TCP:${host}:${port}" 2>/dev/null; then
            echo "${host}:${port} ready"
            return 0
        fi
        sleep 2
        ((counter++))
    done
    echo "timeout waiting for ${host}:${port}"
    return 1
}

# 等待MONITOR_PUBLIC_IP文件写入后获取内容
# 用法: MONITOR_PUBLIC_IP=$(wait_for_monitor_ip)
# 超时5分钟后返回1
wait_for_monitor_ip() {
    local max_retries=60
    local counter=0
    while [ -z "$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null)" ]; do
        echo "waiting for MONITOR_PUBLIC_IP..." >&2
        if [ "$counter" -ge "$max_retries" ]; then
            echo "ERROR: timeout waiting for MONITOR_PUBLIC_IP" >&2
            return 1
        fi
        sleep 5
        ((counter++))
    done
    cat /data/monitor_ip/MONITOR_PUBLIC_IP
}

# sed替换前先转义特殊字符
# 用法: safe_sed PATTERN REPLACEMENT FILE
safe_sed() {
    local pattern="$1" replacement="$2" file="$3"
    pattern=$(printf '%s' "$pattern" | sed 's/[.[\*^$/]/\\&/g')
    replacement=$(printf '%s' "$replacement" | sed 's/[&/\]/\\&/g')
    sed -i "s/${pattern}/${replacement}/g" "$file"
}

# 优雅终止进程,超时后强行杀死
# 用法: kill_graceful TIMEOUT PROC_NAME [PROC_NAME ...]
kill_graceful() {
    local timeout="$1"
    shift
    local names=("$@")
    [ "${#names[@]}" -eq 0 ] && return 0
    killall -15 "${names[@]}" 2>/dev/null || true
    local waited=0 name alive
    while [ "$waited" -lt "$timeout" ]; do
        alive=0
        for name in "${names[@]}"; do
            if pgrep -x "$name" >/dev/null 2>&1; then
                alive=1
                break
            fi
        done
        [ "$alive" -eq 0 ] && return 0
        sleep 1
        waited=$((waited + 1))
    done
    echo "kill_graceful: timeout after ${timeout}s, sending SIGKILL to ${names[*]}"
    killall -9 "${names[@]}" 2>/dev/null || true
    sleep 1
    return 0
}

# 用法: run_or_exit "description" command arg1 arg2 ...
run_or_exit() {
    local desc="$1"
    shift
    "$@"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: ${desc} failed (exit code: ${rc})"
        exit 1
    fi
}

# 启动DBMW服务
# 用法: start_dbmw "server_01"
start_dbmw() {
    local server_id="$1"
    local old_pid
    old_pid=$(pgrep -f "df_dbmw_r ${server_id} start")
    if [ -n "$old_pid" ]; then
        echo "prepare to kill old pid:${old_pid}"
        kill -9 "$old_pid"
    else
        echo "no need to kill process"
    fi
    rm -f "pid/${server_id}.pid"
    LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/home/template/init/libhook.so ./df_dbmw_r "$server_id" start
    sleep 2
    cat "pid/${server_id}.pid" | xargs -n1 -I{} tail --pid={} -f /dev/null
}
