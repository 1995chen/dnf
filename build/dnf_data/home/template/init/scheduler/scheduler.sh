#!/bin/bash
# 定时任务调度器，每个任务使用独立的间隔时间
# 每个任务可单独配置启动后是否立刻执行，否则下次再执行

sg_mysql() {
    mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game -p"$DNF_DB_GAME_PASSWORD" "$@"
}

# 创建当月和下月的拍卖行与金币寄售表
ensure_auction_tables() {
    local cur_dt next_dt dt
    cur_dt=$(date +'%Y%m')
    next_dt=$(date -d "$(date +%Y-%m-01) +1 month" +'%Y%m')
    echo "[auction-table] ensure tables for $cur_dt and $next_dt"
    for dt in "$cur_dt" "$next_dt"; do
        sg_mysql <<EOF
        CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history;
        CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer;
        CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history;
        CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer_$dt LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer;
EOF
    done
}

run_user_script() {
    bash /data/scheduler/user-script.sh
}

# 清理一分钟以前产生的 core dump，防止进程正在写入
clean_core_dumps() {
    local n
    n=$(find /home/neople -type f \( -name 'core' -o -name 'core.*' \) -mmin +1 -print -delete 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] && echo "[core-clean] removed $n core dump file(s)"
    return 0
}

# 按保留月数清理旧的拍卖行表
# AUCTION_RETENTION_MONTHS<=0 时关闭, 默认关闭以免误删历史数据
prune_auction_tables() {
    local months cutoff db tbl suffix
    months="${AUCTION_RETENTION_MONTHS:-0}"
    [ "$months" -gt 0 ] 2>/dev/null || return 0
    cutoff=$(date -d "$(date +%Y-%m-01) -${months} month" +'%Y%m')
    echo "[auction-retention] drop monthly tables older than $cutoff"
    for db in "taiwan_${SERVER_GROUP_DB}_auction_cera" "taiwan_${SERVER_GROUP_DB}_auction_gold"; do
        while IFS= read -r tbl; do
            case "$tbl" in
            auction_history_[0-9][0-9][0-9][0-9][0-9][0-9] | auction_history_buyer_[0-9][0-9][0-9][0-9][0-9][0-9]) ;;
            *) continue ;;
            esac
            suffix="${tbl##*_}"
            if [ "$suffix" -lt "$cutoff" ]; then
                echo "[auction-retention] drop $db.$tbl"
                sg_mysql -e "DROP TABLE IF EXISTS \`$db\`.\`$tbl\`;"
            fi
        done < <(sg_mysql -N -e "SHOW TABLES FROM \`$db\`;" 2>/dev/null)
    done
}

# 数据库定期备份, DB_BACKUP_ENABLE=true 时开启
# 备份路径为 DB_BACKUP_DIR, 只保留最近 DB_BACKUP_KEEP 份
backup_databases() {
    [ "${DB_BACKUP_ENABLE:-false}" = "true" ] || return 0
    if ! command -v mysqldump >/dev/null 2>&1; then
        echo "[db-backup] mysqldump not found, skip" >&2
        return 0
    fi
    local dir="${DB_BACKUP_DIR:-/data/backup}" ts out errf keep f i rc
    local -a dbs backups
    mkdir -p "$dir"
    # 只备份非系统库
    mapfile -t dbs < <(sg_mysql -N -e "SHOW DATABASES;" 2>/dev/null |
        grep -vxE 'information_schema|performance_schema|mysql|sys')
    if [ "${#dbs[@]}" -eq 0 ]; then
        echo "[db-backup] no user databases found, skip" >&2
        return 0
    fi
    ts=$(date +'%Y%m%d-%H%M%S')
    out="$dir/dnf-${ts}.sql.gz"
    errf="$dir/.dump.err"
    echo "[db-backup] dump ${#dbs[@]} database(s) to $out"
    # 原样导出, 防止恢复后不兼容:
    mysqldump -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game -p"$DNF_DB_GAME_PASSWORD" \
        --single-transaction --default-character-set=binary --hex-blob --routines \
        --databases "${dbs[@]}" 2>"$errf" | gzip >"$out"
    rc=${PIPESTATUS[0]}
    if [ "$rc" -ne 0 ]; then
        echo "[db-backup] mysqldump failed (rc=$rc), remove partial $out" >&2
        sed 's/^/[db-backup] /' "$errf" >&2
        rm -f "$out" "$errf"
        return 1
    fi
    rm -f "$errf"
    echo "[db-backup] done: $out"
    # 文件名带时间戳, 保留前 keep 份
    keep="${DB_BACKUP_KEEP:-7}"
    while IFS= read -r f; do
        backups+=("$f")
    done < <(for p in "$dir"/dnf-*.sql.gz; do [ -e "$p" ] && echo "$p"; done | sort -r)
    for ((i = keep; i < ${#backups[@]}; i++)); do
        echo "[db-backup] prune ${backups[$i]}"
        rm -f "${backups[$i]}"
    done
}

# 用法: run_due NAME INTERVAL FUNC
declare -A LAST_RUN
run_due() {
    local name="$1" interval="$2" func="$3" now last
    now=$(date +%s)
    last="${LAST_RUN[$name]:-0}"
    if [ "$((now - last))" -ge "$interval" ]; then
        "$func"
        LAST_RUN[$name]=$now
    fi
}

# 任务是否在容器启动后立刻执行
# 不立刻执行则把上次执行时间设置为启动时间并跳过
# 用法: seed_skip_first NAME RUN_ON_START START_TS
seed_skip_first() {
    local name="$1" on_start="$2" start_ts="$3"
    [ "$on_start" = "true" ] && return 0
    LAST_RUN[$name]=$start_ts
}

main() {
    local tick start_ts
    tick="${SCHEDULER_TICK:-60}"
    start_ts=$(date +%s)
    seed_skip_first auction_tables "${AUCTION_TABLE_RUN_ON_START:-true}" "$start_ts"
    seed_skip_first geo_allow "${GEO_ALLOW_RUN_ON_START:-true}" "$start_ts"
    seed_skip_first core_clean "${CORE_CLEAN_RUN_ON_START:-false}" "$start_ts"
    seed_skip_first auction_retention "${AUCTION_RETENTION_RUN_ON_START:-false}" "$start_ts"
    seed_skip_first db_backup "${DB_BACKUP_RUN_ON_START:-false}" "$start_ts"
    while true; do
        run_due auction_tables "${AUCTION_TABLE_INTERVAL:-3600}" ensure_auction_tables
        run_due geo_allow "${GEO_ALLOW_INTERVAL:-3600}" run_user_script
        run_due core_clean "${CORE_CLEAN_INTERVAL:-86400}" clean_core_dumps
        run_due auction_retention "${AUCTION_RETENTION_INTERVAL:-86400}" prune_auction_tables
        run_due db_backup "${DB_BACKUP_INTERVAL:-86400}" backup_databases
        sleep "$tick"
    done
}

# 被 source 时只加载函数
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi
