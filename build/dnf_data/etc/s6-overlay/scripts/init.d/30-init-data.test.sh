#!/bin/bash
# 30-init-data.sh 数据初始化幂等性测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/30-init-data.sh"
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../../../../home/template/init/lib" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 空 init.sh, 避免触发 mysql 初始化
init_stub_file="$WORK/init-stub.sh"
echo 'exit 0' >"$init_stub_file"

# 配置模板
tpl_path="$WORK/template/neople"
mkdir -p "$tpl_path/game/cfg"
cat >"$tpl_path/game/cfg/test.cfg" <<'EOF'
game_pwd=GAME_PASSWORD
dec_pwd=DEC_GAME_PWD
grp_name=SERVER_GROUP_NAME
grp_db=SERVER_GROUP_DB
grp=SERVER_GROUP
EOF
echo 'tbl_grp=SERVER_GROUP' >"$tpl_path/game/test.tbl"
echo junk >"$tpl_path/game/old.log"
echo junk >"$tpl_path/game/old.pid"
echo junk >"$tpl_path/game/core.999"

# 创建 dbmw 目录
mkdir -p "$tpl_path/dbmw_guild/cfg" "$tpl_path/dbmw_mnt/cfg" "$tpl_path/dbmw_stat/cfg"

# 版本文件 + dp 目录
data_path="$WORK/data"
mkdir -p "$data_path/dp"
echo pvf >"$data_path/Script.pvf"
echo gamebin >"$data_path/df_game_r"
echo pubkey >"$data_path/publickey.pem"

# df_dbmw_r
dbmw_bin="$WORK/df_dbmw_r"
echo dbmwbin >"$dbmw_bin"

dest_path="$WORK/neople"

run_hook() {
    DNF_LIB_PATH="$LIB_PATH" \
        INIT_SCRIPT_FILE="$init_stub_file" \
        TEMPLATE_NEOPLE_PATH="$tpl_path" \
        NEOPLE_TMP_PATH="$WORK/template/neople-tmp" \
        NEOPLE_PATH="$dest_path" \
        DATA_PATH="$data_path" \
        DBMW_BIN_FILE="$dbmw_bin" \
        DNF_DB_GAME_PASSWORD=gamepwd \
        DEC_GAME_PWD=decpwd \
        SERVER_GROUP_NAME=siroco \
        SERVER_GROUP_DB=dnf3db \
        SERVER_GROUP=3 \
        bash "$HOOK"
}

failed=0
pass=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
    else
        printf "FAIL %-40s expected=[%s] got=[%s]\n" "$1" "$2" "$3"
        failed=1
    fi
}
exists() { [ -e "$1" ] && echo yes || echo no; }

expected_cfg=$'game_pwd=gamepwd\ndec_pwd=decpwd\ngrp_name=siroco\ngrp_db=dnf3db\ngrp=3'

# 首次运行
run_hook >/dev/null 2>&1
chk "首次退出码" 0 "$?"
chk "cfg 占位符替换" "$expected_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"
chk "tbl SERVER_GROUP 替换" "tbl_grp=3" "$(cat "$dest_path/game/test.tbl")"
chk "清理 .log" no "$(exists "$dest_path/game/old.log")"
chk "清理 .pid" no "$(exists "$dest_path/game/old.pid")"
chk "清理 core.*" no "$(exists "$dest_path/game/core.999")"
chk "复制 Script.pvf" yes "$(exists "$dest_path/game/Script.pvf")"
chk "复制 df_game_r" yes "$(exists "$dest_path/game/df_game_r")"
chk "复制 publickey.pem" yes "$(exists "$dest_path/game/publickey.pem")"
chk "清理临时目录" no "$(exists "$WORK/template/neople-tmp")"
chk "复制 df_dbmw_r 到 dbmw_guild" yes "$(exists "$dest_path/dbmw_guild/df_dbmw_r")"
chk "复制 df_dbmw_r 到 dbmw_mnt" yes "$(exists "$dest_path/dbmw_mnt/df_dbmw_r")"
chk "复制 df_dbmw_r 到 dbmw_stat" yes "$(exists "$dest_path/dbmw_stat/df_dbmw_r")"
chk "dbmw 复制成功" "dbmwbin" "$(cat "$dest_path/dbmw_guild/df_dbmw_r")"

fp1_cfg=$(cat "$dest_path/game/cfg/test.cfg")
fp1_list=$(find "$dest_path/game" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)

# 第二次运行验证幂等
run_hook >/dev/null 2>&1
chk "二次退出码" 0 "$?"
chk "二次 cfg 内容不变" "$fp1_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"
chk "二次 game 文件列表不变" "$fp1_list" "$(find "$dest_path/game" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)"
chk "二次 cfg 内容正确" "$expected_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
