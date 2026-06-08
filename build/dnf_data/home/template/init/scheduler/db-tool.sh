#!/bin/bash
# 数据库备份与恢复工具
# 用法:
#   db-tool.sh backup
#       立即备份所有非系统库到 DB_BACKUP_DIR, 只保留最近 DB_BACKUP_KEEP 份
#   db-tool.sh restore [latest|<文件名|路径>]
#       从备份恢复, 默认只列出受影响的库, 设 DB_RESTORE_CONFIRM=yes 才执行
# 容器内执行:
#   docker exec <容器> /home/template/init/scheduler/db-tool.sh backup
#   docker exec -e DB_RESTORE_CONFIRM=yes <容器> /home/template/init/scheduler/db-tool.sh restore latest

# shellcheck disable=SC2153
env_path="${CONTAINER_ENV_PATH:-/run/s6/container_environment}"

# 优先用已有环境变量, 否则从 s6 container_environment 读取, 供 docker exec 使用
load_var() {
    local v="$1" val
    [ -n "${!v}" ] && return 0
    if [ -f "$env_path/$v" ]; then
        val=$(cat "$env_path/$v")
        export "$v=$val"
    fi
    return 0
}

cmd_backup() {
    local v dir ts out errf keep f i rc
    local -a dbs backups
    for v in CUR_SG_DB_HOST CUR_SG_DB_PORT DNF_DB_GAME_PASSWORD; do load_var "$v"; done
    if ! command -v mysqldump >/dev/null 2>&1; then
        echo "[db-backup] mysqldump not found, skip" >&2
        return 0
    fi
    if [ -z "$CUR_SG_DB_HOST" ] || [ -z "$DNF_DB_GAME_PASSWORD" ]; then
        echo "[db-backup] db connection not resolved, run this inside the dnf container" >&2
        return 1
    fi
    dir="${DB_BACKUP_DIR:-/data/backup}"
    mkdir -p "$dir"
    # 只备份非系统库
    mapfile -t dbs < <(MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game \
        -N -e "SHOW DATABASES;" 2>/dev/null |
        grep -vxE 'information_schema|performance_schema|mysql|sys')
    if [ "${#dbs[@]}" -eq 0 ]; then
        echo "[db-backup] no user databases found, skip" >&2
        return 0
    fi
    ts=$(date +'%Y%m%d-%H%M%S')
    out="$dir/dnf-${ts}.sql.gz"
    errf="$dir/.dump.err"
    echo "[db-backup] dump ${#dbs[@]} database(s) to $out"
    # 兼容跨版本恢复, 如 5.0 备份恢复到 5.7
    MYSQL_PWD="$DNF_DB_GAME_PASSWORD" mysqldump -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u game \
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

cmd_restore() {
    local v dir sel file zrc mrc
    local -a rcs
    for v in CUR_SG_DB_HOST CUR_SG_DB_PORT CUR_SG_DB_ROOT_PASSWORD; do load_var "$v"; done
    dir="${DB_BACKUP_DIR:-/data/backup}"
    sel="${1:-latest}"
    # latest 使用最新文件, 若包含 / 则视为绝对路径, 否则当作备份目录下的文件名
    if [ "$sel" = latest ]; then
        file=$(for p in "$dir"/dnf-*.sql.gz; do [ -e "$p" ] && echo "$p"; done | sort -r | head -n 1)
    else
        case "$sel" in
        */*) file="$sel" ;;
        *) file="$dir/$sel" ;;
        esac
    fi
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "[db-restore] backup not found: ${file:-(none in $dir)}" >&2
        echo "[db-restore] available backups in $dir:" >&2
        for p in "$dir"/dnf-*.sql.gz; do [ -e "$p" ] && echo "  $(basename "$p")" >&2; done
        return 1
    fi
    if [ -z "$CUR_SG_DB_HOST" ] || [ -z "$CUR_SG_DB_ROOT_PASSWORD" ]; then
        echo "[db-restore] db connection not resolved, run this inside the dnf container" >&2
        return 1
    fi
    echo "[db-restore] target : ${CUR_SG_DB_HOST}:${CUR_SG_DB_PORT}"
    echo "[db-restore] file   : $file"
    echo "[db-restore] databases contained in this backup:"
    gzip -dc "$file" 2>/dev/null | grep -iE '^CREATE DATABASE' | sed 's/^/  /'
    if [ "${DB_RESTORE_CONFIRM:-}" != "yes" ]; then
        echo "[db-restore] DRY-RUN: would OVERWRITE the databases listed above"
        echo "[db-restore] re-run with -e DB_RESTORE_CONFIRM=yes to apply"
        return 0
    fi
    echo "[db-restore] restoring, this overwrites current data ..."
    gzip -dc "$file" | MYSQL_PWD="$CUR_SG_DB_ROOT_PASSWORD" mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root
    rcs=("${PIPESTATUS[@]}")
    zrc=${rcs[0]}
    mrc=${rcs[1]}
    if [ "$zrc" -ne 0 ] || [ "$mrc" -ne 0 ]; then
        echo "[db-restore] FAILED (gzip rc=$zrc, mysql rc=$mrc)" >&2
        return 1
    fi
    echo "[db-restore] done"
    echo "[db-restore] restart the container to load the new data: docker restart <container>"
}

usage() {
    echo "usage: db-tool.sh {backup | restore [latest|<file>]}" >&2
}

main() {
    local sub="${1:-}"
    [ -n "$sub" ] && shift
    case "$sub" in
    backup) cmd_backup "$@" ;;
    restore) cmd_restore "$@" ;;
    *)
        usage
        exit 2
        ;;
    esac
}

# 被 source 时只加载函数
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
