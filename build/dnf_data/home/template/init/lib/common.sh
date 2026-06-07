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
    killall -q -15 "${names[@]}" || true
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
    killall -q -9 "${names[@]}" || true
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

# 比较两个文件内容是否一致, 一致返回 0
files_identical() {
    [ -f "$1" ] && [ -f "$2" ] || return 1
    cmp -s "$1" "$2"
}

# 同步模板文件
# 用法: sync_template_file SRC TARGET REF
sync_template_file() {
    local src="$1" target="$2" ref="$3"
    local name backup ts
    name=$(basename "$target")
    if [ ! -f "$target" ]; then
        cp -f "$src" "$target"
        cp -f "$src" "$ref"
        echo "init $name success"
        return 0
    fi
    if files_identical "$src" "$target"; then
        cp -f "$src" "$ref"
        echo "$name have already inited, do nothing!"
        return 0
    fi
    if files_identical "$src" "$ref"; then
        echo "keep customized $name, not overwritten"
        return 0
    fi
    if [ ! -f "$ref" ] || ! files_identical "$target" "$ref"; then
        ts=$(date +'%Y%m%d-%H%M%S')
        backup="${target}.${ts}.bak"
        cp -f "$target" "$backup"
        echo "backup customized $name -> $(basename "$backup")"
    fi
    cp -f "$src" "$target"
    cp -f "$src" "$ref"
    echo "regenerate $name: template updated"
}

# 创建 /home/neople 目录
#
# 配置类 cfg/tbl/xml/template 文件从 template 复制
# 二进制与只读文件按文件名或后缀创建指向 template 的软链接
# 其它文件按大小分类处理，大于等于阈值则使用软链接，小于阈值则复制
#
# template 的软链接与特殊文件原样复制
#
# 阈值默认为 512K
#
# 用法: build_neople_tree SRC DST [MIN_LINK_BYTES]
build_neople_tree() {
    local src="$1" dst="$2" min_link_bytes="${3:-524288}"
    local d f rel sz base action s
    if ! mkdir -p "$dst"; then
        echo "ERROR: build_neople_tree mkdir failed for $dst" >&2
        return 1
    fi
    while IFS= read -r -d '' d; do
        [ "$d" = "$src" ] && continue
        rel="${d#"$src"/}"
        if ! mkdir -p "$dst/$rel"; then
            echo "ERROR: build_neople_tree mkdir failed for $dst/$rel" >&2
            return 1
        fi
    done < <(find "$src" -type d -print0)
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        # 先删除已有的文件，防止重复运行时将内容写回 template
        if ! rm -f "$dst/$rel"; then
            echo "ERROR: build_neople_tree rm failed for $rel" >&2
            return 1
        fi
        base="${rel##*/}"
        case "$base" in
        # 配置文件需要动态生成，需要复制，否则会污染 template
        *.cfg | *.tbl | *.xml | *.template)
            action='copy'
            ;;
        # 运行时被进程读写的文件, 需要复制
        iteminfo.dat | channel_info.etc)
            action='copy'
            ;;
        # 只读的二进制与数据文件, 无视大小一律使用软链接
        df_* | secagent | zergsvr | gunnersvr | \
            *.so | *.so.* | *.exe | *.ttf | *.ttc | \
            *.mhe | *.dib | *.dat | *.bin | *.hsb | *.key | *.etc | *.str)
            action='link'
            ;;
        # 其它文件按大小分类处理，大于等于阈值则使用软链接，小于阈值则复制
        *)
            sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
            if [ "$sz" -ge "$min_link_bytes" ]; then action='link'; else action='copy'; fi
            ;;
        esac
        if [ "$action" = link ]; then
            if ! ln -sfn "$f" "$dst/$rel"; then
                echo "ERROR: build_neople_tree symlink failed for $rel" >&2
                return 1
            fi
        else
            if ! cp -pf "$f" "$dst/$rel"; then
                echo "ERROR: build_neople_tree copy failed for $rel" >&2
                return 1
            fi
        fi
    done < <(find "$src" -type f -print0)
    # template 里的软链与特殊文件(fifo等)按原样复制, 保留软链接与文件类型
    while IFS= read -r -d '' s; do
        rel="${s#"$src"/}"
        if ! rm -f "$dst/$rel"; then
            echo "ERROR: build_neople_tree rm failed for $rel" >&2
            return 1
        fi
        if ! cp -a "$s" "$dst/$rel"; then
            echo "ERROR: build_neople_tree copy special failed for $rel" >&2
            return 1
        fi
    done < <(find "$src" ! -type d ! -type f -print0)
    return 0
}

# 将文件中所有 __VAR__ 标记替换为对应环境变量值
# env-resolve.sh 已确保所有环境变量非空
# 用法: substitute_port_markers <file>
substitute_port_markers() {
    local file="$1" v
    for v in AUCTION_TCP_PORT BRIDGE_TCP_PORT CHANNEL_TCP_PORT COMMUNITY_TCP_PORT \
        GUILD_TCP_PORT MANAGER_TCP_PORT MONITOR_TCP_PORT POINT_TCP_PORT RELAY_TCP_PORT \
        DBMW_GUILD_TCP_PORT DBMW_MNT_TCP_PORT DBMW_STAT_TCP_PORT \
        COSERVER_UDP_PORT STATICS_UDP_PORT \
        MAIN_DB_PROXY_PORT SG_DB_PROXY_PORT; do
        safe_sed "__${v}__" "${!v}" "$file"
    done
}

# 从 zergsvrd.xml 的 self_svr_info 解析 self_cfg 的 svr_type 与 svr_id
# 用法: zerg_parse_self <zergsvrd.xml>; 输出 "type id"
zerg_parse_self() {
    awk '
        function num(s) { sub(/^[^>]*>/, "", s); sub(/<.*/, "", s); gsub(/[^0-9]/, "", s); return s }
        /<self_svr_info[[:space:]>]/ { in_self = 1 }
        in_self && /<svr_type[[:space:]>]/ { t = num($0) }
        in_self && /<svr_id[[:space:]>]/   { i = num($0) }
        /<\/self_svr_info>/ { if (in_self) { print t, i; exit } }
    ' "$1"
}

# 根据 svr_type_ 与 svr_id_ 从 svcid.xml 获取监听端口
# 用法: svcid_lookup_port <svcid.xml> <type> <id>; 输出端口
svcid_lookup_port() {
    awk -v wt="$2" -v wi="$3" '
        function num(s) { sub(/^[^>]*>/, "", s); sub(/<.*/, "", s); gsub(/[^0-9]/, "", s); return s }
        /<service_info_[[:space:]>]/ { ct = ""; ci = "" }
        /<svr_type_[[:space:]>]/ { ct = num($0) }
        /<svr_id_[[:space:]>]/   { ci = num($0) }
        /<svr_port_[[:space:]>]/ { p = num($0); if (ct == wt && ci == wi) { print p; exit } }
    ' "$1"
}

# 将 svcid.xml 中匹配 type 与 id 的 service_info_ 端口改为新端口
# 用法: svcid_rewrite_port <svcid.xml> <type> <id> <new_port>
svcid_rewrite_port() {
    local file="$1" wt="$2" wi="$3" np="$4" tmp
    tmp="${file}.tmp.$$"
    awk -v wt="$wt" -v wi="$wi" -v np="$np" '
        function num(s) { sub(/^[^>]*>/, "", s); sub(/<.*/, "", s); gsub(/[^0-9]/, "", s); return s }
        /<service_info_[[:space:]>]/ { ct = ""; ci = "" }
        /<svr_type_[[:space:]>]/ { ct = num($0) }
        /<svr_id_[[:space:]>]/   { ci = num($0) }
        /<svr_port_[[:space:]>]/ && ct == wt && ci == wi {
            sub(/<svr_port_>[^<]*<\/svr_port_>/, "<svr_port_> " np " </svr_port_>")
        }
        { print }
    ' "$file" >"$tmp" && mv "$tmp" "$file"
}

# 启动DBMW服务
# 用法: start_dbmw "server_01"
start_dbmw() {
    local server_id="$1"
    local old_pid
    old_pid=$(pgrep -f "df_dbmw_r ${server_id}")
    if [ -n "$old_pid" ]; then
        echo "prepare to kill old pid:${old_pid}"
        kill -9 "$old_pid"
    else
        echo "no need to kill process"
    fi
    rm -f "pid/${server_id}.pid"
    # shellcheck source=./tune.sh
    source /home/template/init/lib/tune.sh
    tune_apply_malloc_conf_32
    exec env LD_PRELOAD=/usr/lib/libjemalloc32.so.2:/home/template/init/libhook.so \
        ./df_dbmw_r "$server_id" nofork
}
