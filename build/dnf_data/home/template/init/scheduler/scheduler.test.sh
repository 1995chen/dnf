#!/bin/bash

# shellcheck disable=SC2034,SC2329
SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=./scheduler.sh
source "${SCRIPT_PATH}/scheduler.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-46s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}

COUNT=0
inc() { COUNT=$((COUNT + 1)); }
LAST_RUN=()
run_due t1 100 inc
chk "run_due 首次执行" 1 "$COUNT"
run_due t1 100 inc
chk "run_due 一个周期内不重复执行" 1 "$COUNT"
LAST_RUN["t1"]=0
run_due t1 100 inc
chk "run_due 到期则再次执行" 2 "$COUNT"

# 是否启动后立刻执行
LAST_RUN=()
RAN=0
mark() { RAN=$((RAN + 1)); }
now0=$(date +%s)
# 不立刻执行: 设置上次执行时间, 跳过首次执行
seed_skip_first t_skip false "$now0"
run_due t_skip 3600 mark
chk "不立刻执行-跳过" 0 "$RAN"
# 立刻执行: 不设置上次执行时间
seed_skip_first t_now true "$now0"
run_due t_now 3600 mark
chk "立刻执行" 1 "$RAN"

# 创建当月与下月数据表
SQLLOG="$WORK/sql.log"
: >"$SQLLOG"
SERVER_GROUP_DB=cain
sg_mysql() { cat >>"$SQLLOG"; }
ensure_auction_tables >/dev/null
cur=$(date +'%Y%m')
nxt=$(date -d "$(date +%Y-%m-01) +1 month" +'%Y%m')
chk "创建当月 cera 表" yes \
    "$(grep -q "auction_history_${cur} LIKE taiwan_cain_auction_cera.auction_history;" "$SQLLOG" && echo yes || echo no)"
chk "创建下月 gold 表" yes \
    "$(grep -q "auction_history_${nxt} LIKE taiwan_cain_auction_gold.auction_history;" "$SQLLOG" && echo yes || echo no)"
chk "不再使用老牛版本的 201603 表" 0 "$(grep -c "201603" "$SQLLOG")"

# prune_auction_tables 只删早于 cutoff 的表
cutoff=$(date -d "$(date +%Y-%m-01) -2 month" +'%Y%m')
older1=$(date -d "$(date +%Y-%m-01) -3 month" +'%Y%m')
older2=$(date -d "$(date +%Y-%m-01) -5 month" +'%Y%m')
keep_cur=$(date +'%Y%m')
FAKE_TABLES=(
    auction_history auction_history_buyer auction_average_price
    "auction_history_${older1}" "auction_history_${older2}"
    "auction_history_${cutoff}" "auction_history_${keep_cur}"
    "auction_history_buyer_${older1}" "auction_history_buyer_${keep_cur}"
)
DROPLOG="$WORK/drop.log"
: >"$DROPLOG"
sg_mysql() {
    case "$*" in
    *"SHOW TABLES"*) printf '%s\n' "${FAKE_TABLES[@]}" ;;
    *"DROP TABLE"*) printf '%s\n' "$*" >>"$DROPLOG" ;;
    esac
}

AUCTION_RETENTION_MONTHS=0 prune_auction_tables
chk "保留月数=0 时不删任何表" 0 "$(wc -l <"$DROPLOG")"

: >"$DROPLOG"
AUCTION_RETENTION_MONTHS=2 prune_auction_tables
chk "删早于 cutoff 的 ${older1}" yes "$(grep -qE "auction_history_${older1}\`" "$DROPLOG" && echo yes || echo no)"
chk "删早于 cutoff 的 ${older2}" yes "$(grep -qE "auction_history_${older2}\`" "$DROPLOG" && echo yes || echo no)"
chk "删 buyer_${older1}" yes "$(grep -qE "auction_history_buyer_${older1}\`" "$DROPLOG" && echo yes || echo no)"
chk "保留 cutoff 当月 ${cutoff}" no "$(grep -qE "auction_history_${cutoff}\`" "$DROPLOG" && echo yes || echo no)"
chk "保留当月 ${keep_cur}" no "$(grep -qE "auction_history_${keep_cur}\`" "$DROPLOG" && echo yes || echo no)"
chk "不删 auction_history" no "$(grep -qE "auction_history\`" "$DROPLOG" && echo yes || echo no)"
chk "不删 auction_average_price" no "$(grep -q "auction_average_price" "$DROPLOG" && echo yes || echo no)"

CALLLOG="$WORK/dbtool.log"
stub_tool="$WORK/db-tool.sh"
cat >"$stub_tool" <<EOF
#!/bin/bash
echo "\$*" >>"$CALLLOG"
EOF
chmod +x "$stub_tool"
DB_TOOL="$stub_tool"

: >"$CALLLOG"
unset DB_BACKUP_ENABLE
backup_databases
chk "默认关闭时不触发数据库备份" 0 "$(grep -c . "$CALLLOG")"

: >"$CALLLOG"
DB_BACKUP_ENABLE=true backup_databases
chk "开启时调用 db-tool backup 备份数据库" yes "$(grep -qx backup "$CALLLOG" && echo yes || echo no)"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
