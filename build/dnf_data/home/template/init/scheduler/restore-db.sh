#!/bin/bash
# 数据库恢复脚本
# 用法: docker exec [-e DB_RESTORE_CONFIRM=yes] <容器> \
#         /home/template/init/scheduler/restore-db.sh [latest|<文件名|路径>]
# 默认只显示受影响的库; 设置 DB_RESTORE_CONFIRM=yes 才真正执行恢复动作

# shellcheck disable=SC2153
env_path="${CONTAINER_ENV_PATH:-/run/s6/container_environment}"

load_var() {
    local v="$1" val
    [ -n "${!v}" ] && return 0
    if [ -f "$env_path/$v" ]; then
        val=$(cat "$env_path/$v")
        export "$v=$val"
    fi
    return 0
}
for v in CUR_SG_DB_HOST CUR_SG_DB_PORT CUR_SG_DB_ROOT_PASSWORD; do
    load_var "$v"
done

dir="${DB_BACKUP_DIR:-/data/backup}"
sel="${1:-latest}"

# 选择备份文件，latest 使用最新版本，带 / 视为绝对路径，否则当作备份目录下的文件名
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
    exit 1
fi

if [ -z "$CUR_SG_DB_HOST" ] || [ -z "$CUR_SG_DB_ROOT_PASSWORD" ]; then
    echo "[db-restore] db connection not resolved, run this inside the dnf container" >&2
    exit 1
fi

echo "[db-restore] target : ${CUR_SG_DB_HOST}:${CUR_SG_DB_PORT}"
echo "[db-restore] file   : $file"
echo "[db-restore] databases contained in this backup:"
gzip -dc "$file" 2>/dev/null | grep -iE '^CREATE DATABASE' | sed 's/^/  /'

if [ "${DB_RESTORE_CONFIRM:-}" != "yes" ]; then
    echo "[db-restore] DRY-RUN: would OVERWRITE the databases listed above"
    echo "[db-restore] re-run with -e DB_RESTORE_CONFIRM=yes to apply"
    exit 0
fi

echo "[db-restore] restoring, this overwrites current data ..."
gzip -dc "$file" | mysql -h "$CUR_SG_DB_HOST" -P "$CUR_SG_DB_PORT" -u root -p"$CUR_SG_DB_ROOT_PASSWORD"
zrc=${PIPESTATUS[0]}
mrc=${PIPESTATUS[1]}
if [ "$zrc" -ne 0 ] || [ "$mrc" -ne 0 ]; then
    echo "[db-restore] FAILED (gzip rc=$zrc, mysql rc=$mrc)" >&2
    exit 1
fi
echo "[db-restore] done"
