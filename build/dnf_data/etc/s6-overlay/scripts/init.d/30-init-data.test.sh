#!/bin/bash
# 30-init-data.sh 数据初始化幂等性测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/30-init-data.sh"
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../../../../home/template/init/lib" &>/dev/null && pwd)
# shellcheck source=../../../../home/template/init/lib/common.sh
source "${LIB_PATH}/common.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 配置模板
tpl_path="$WORK/template/neople"
mkdir -p "$tpl_path/game/cfg"
cat >"$tpl_path/game/cfg/test.cfg" <<'EOF'
game_pwd=__GAME_PASSWORD__
dec_pwd=__DEC_GAME_PWD__
grp_name=__SERVER_GROUP_NAME__
grp_db=__SERVER_GROUP_DB__
grp=__SERVER_GROUP__
auction_port=__AUCTION_TCP_PORT__
db_port=__MAIN_DB_PROXY_PORT__
coserver_port=__COSERVER_UDP_PORT__
statics_port=__STATICS_UDP_PORT__
EOF
printf 'tbl_grp=__SERVER_GROUP__\ntbl_port=__STATICS_UDP_PORT__\n' >"$tpl_path/game/test.tbl"
echo junk >"$tpl_path/game/old.log"
echo junk >"$tpl_path/game/old.pid"
echo junk >"$tpl_path/game/core.999"

dd if=/dev/zero of="$tpl_path/game/bigbin.so" bs=1024 count=1100 2>/dev/null
dd if=/dev/zero of="$tpl_path/game/old-big.log" bs=1024 count=1100 2>/dev/null

printf 'grp=__SERVER_GROUP__\n' >"$tpl_path/game/cfg/big.cfg"
dd if=/dev/zero bs=1024 count=1200 2>/dev/null | tr '\0' x >>"$tpl_path/game/cfg/big.cfg"

printf 'x' >"$tpl_path/game/small.dib"

mkdir -p "$tpl_path/point" "$tpl_path/auction"
: >"$tpl_path/point/iteminfo.dat"
printf 'itemdata' >"$tpl_path/auction/iteminfo.dat"

mkdir -p "$tpl_path/game/channel_info"
printf 'chinfo' >"$tpl_path/game/channel_info/channel_info.etc"

# 创建 dbmw 目录
mkdir -p "$tpl_path/dbmw_guild/cfg" "$tpl_path/dbmw_mnt/cfg" "$tpl_path/dbmw_stat/cfg"

# secagent / svcid xml: 验证 xml 标记替换与 svcid 端口更新
mkdir -p "$tpl_path/secsvr/zergsvr/cfg"
printf '<config>\n\t<gamesvr_channel_num_>__SECAGENT_CHANNEL_NUM__</gamesvr_channel_num_>\n</config>\n' \
    >"$tpl_path/secsvr/zergsvr/cfg/secagent_config.xml"
# 非self: (31,570001) 与 self: (30,570011), 只更新 self
printf '<svcid_config>\n\t<service_info_>\n\t\t<svr_type_> 31 </svr_type_>\n\t\t<svr_id_> 570001 </svr_id_>\n\t\t<svr_port_> 9000 </svr_port_>\n\t</service_info_>\n\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_id_> 570011 </svr_id_>\n\t\t<svr_port_> 9000 </svr_port_>\n\t</service_info_>\n</svcid_config>\n' \
    >"$tpl_path/secsvr/zergsvr/cfg/svcid.xml"

# 版本文件 + dp 目录
data_path="$WORK/data"
mkdir -p "$data_path/dp"
echo pvf >"$data_path/Script.pvf"
echo gamebin >"$data_path/df_game_r"
echo pubkey >"$data_path/publickey.pem"

# df_dbmw_r
dbmw_bin="$WORK/df_dbmw_r"
echo dbmwbin >"$dbmw_bin"

# 文件初始化模板
tinit="$WORK/tinit"
mkdir -p "$tinit/run" "$tinit/monitor_ip" "$tinit/scheduler"
echo libhook >"$tinit/libhook.so"
echo fridajs >"$tinit/frida.js"
echo getip >"$tinit/monitor_ip/get_public_ip.sh"
echo startgate >"$tinit/run/start_gate.sh"
echo userscript >"$tinit/scheduler/user-script.sh"

dest_path="$WORK/neople"

run_hook() {
    DNF_LIB_PATH="$LIB_PATH" \
        TEMPLATE_NEOPLE_PATH="$tpl_path" \
        NEOPLE_PATH="$dest_path" \
        DATA_PATH="$data_path" \
        TEMPLATE_INIT_PATH="$tinit" \
        DBMW_BIN_FILE="$dbmw_bin" \
        DNF_DB_GAME_PASSWORD=gamepwd \
        DEC_GAME_PWD=decpwd \
        SERVER_GROUP_NAME=siroco \
        SERVER_GROUP_DB=dnf3db \
        SERVER_GROUP=3 \
        AUCTION_TCP_PORT=30803 \
        MAIN_DB_PROXY_PORT=3307 \
        COSERVER_UDP_PORT=30703 \
        STATICS_UDP_PORT=30503 \
        SECAGENT_CHANNEL_NUM=12 \
        ZERGSVR_SELF_TYPE=30 \
        ZERGSVR_SELF_ID=570011 \
        ZERGSVR_PORT=9500 \
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

expected_cfg=$'game_pwd=gamepwd\ndec_pwd=decpwd\ngrp_name=siroco\ngrp_db=dnf3db\ngrp=3\nauction_port=30803\ndb_port=3307\ncoserver_port=30703\nstatics_port=30503'

# 首次运行
run_hook >/dev/null 2>&1
chk "首次退出码" 0 "$?"
chk "cfg 占位符替换" "$expected_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"
chk "tbl SERVER_GROUP 替换" "tbl_grp=3" "$(grep tbl_grp "$dest_path/game/test.tbl")"
chk "tbl 端口标记替换" "tbl_port=30503" "$(grep tbl_port "$dest_path/game/test.tbl")"
chk "清理 .log" no "$(exists "$dest_path/game/old.log")"
chk "清理 .pid" no "$(exists "$dest_path/game/old.pid")"
chk "清理 core.*" no "$(exists "$dest_path/game/core.999")"
chk "清理大日志文件软链接" no "$(exists "$dest_path/game/old-big.log")"
chk "Script.pvf 软链接存在" yes "$(exists "$dest_path/game/Script.pvf")"
chk "Script.pvf 软链接指向 /data/Script.pvf" "$data_path/Script.pvf" "$(readlink "$dest_path/game/Script.pvf")"
chk "df_game_r 软链接存在" yes "$(exists "$dest_path/game/df_game_r")"
chk "df_game_r 软链接指向 /data/df_game_r" "$data_path/df_game_r" "$(readlink "$dest_path/game/df_game_r")"
chk "复制 publickey.pem" yes "$(exists "$dest_path/game/publickey.pem")"
chk "大文件使用 /home/template 软链接" "$tpl_path/game/bigbin.so" "$(readlink "$dest_path/game/bigbin.so")"
chk "大文件为软链接" yes "$([ -L "$dest_path/game/bigbin.so" ] && echo yes || echo no)"
chk "cfg 小文件不使用软链接" no "$([ -L "$dest_path/game/cfg/test.cfg" ] && echo yes || echo no)"
chk "大配置不使用软链接" no "$([ -L "$dest_path/game/cfg/big.cfg" ] && echo yes || echo no)"
chk "大配置文件替换正常" "grp=3" "$(grep '^grp=' "$dest_path/game/cfg/big.cfg")"
chk "小只读文件使用软链接 .dib" yes "$([ -L "$dest_path/game/small.dib" ] && echo yes || echo no)"
chk "iteminfo.dat 复制到 point" no "$([ -L "$dest_path/point/iteminfo.dat" ] && echo yes || echo no)"
chk "iteminfo.dat 复制到 auction" no "$([ -L "$dest_path/auction/iteminfo.dat" ] && echo yes || echo no)"
chk "channel_info.etc 复制到 game" no "$([ -L "$dest_path/game/channel_info/channel_info.etc" ] && echo yes || echo no)"
chk "dbmw_guild 软链接存在" yes "$(exists "$dest_path/dbmw_guild/df_dbmw_r")"
chk "dbmw_mnt 软链接存在" yes "$(exists "$dest_path/dbmw_mnt/df_dbmw_r")"
chk "dbmw_stat 软链接存在" yes "$(exists "$dest_path/dbmw_stat/df_dbmw_r")"
chk "df_dbmw_r 软链正确" "$dbmw_bin" "$(readlink "$dest_path/dbmw_guild/df_dbmw_r")"
chk "df_dbmw_r 可读" "dbmwbin" "$(cat "$dest_path/dbmw_guild/df_dbmw_r")"

chk "生成 privatekey.pem" yes "$(exists "$data_path/privatekey.pem")"
chk "生成 publickey.pem" yes "$(exists "$data_path/publickey.pem")"
chk "复制 libhook.so 到 dp" yes "$(exists "$data_path/dp/libhook.so")"
chk "更新 frida.js" "fridajs" "$(cat "$data_path/frida.js" 2>/dev/null)"
chk "复制 get_public_ip.sh" yes "$(exists "$data_path/monitor_ip/get_public_ip.sh")"
chk "更新 run/start_gate.sh" "startgate" "$(cat "$data_path/run/start_gate.sh" 2>/dev/null)"
chk "更新 scheduler/user-script.sh" "userscript" "$(cat "$data_path/scheduler/user-script.sh" 2>/dev/null)"

# xml 标记替换与 svcid 更新
secagent_dest="$dest_path/secsvr/zergsvr/cfg/secagent_config.xml"
svcid_dest="$dest_path/secsvr/zergsvr/cfg/svcid.xml"
chk "secagent 频道数替换" "12" "$(sed -n 's:.*<gamesvr_channel_num_>\([0-9]*\)</gamesvr_channel_num_>.*:\1:p' "$secagent_dest")"
chk "svcid self(30/570011) 端口更新为 9500" "9500" "$(svcid_lookup_port "$svcid_dest" 30 570011)"
chk "svcid 非 self(31/570001) 端口保持不变 9000" "9000" "$(svcid_lookup_port "$svcid_dest" 31 570001)"

fp1_cfg=$(cat "$dest_path/game/cfg/test.cfg")
fp1_list=$(find "$dest_path/game" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)

# 第二次运行验证幂等
run_hook >/dev/null 2>&1
chk "二次运行退出码" 0 "$?"
chk "二次运行 cfg 内容不变" "$fp1_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"
chk "二次运行 game 文件列表不变" "$fp1_list" "$(find "$dest_path/game" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)"
chk "二次运行 cfg 内容正确" "$expected_cfg" "$(cat "$dest_path/game/cfg/test.cfg")"
chk "二次初始化 Script.pvf 时，软链接仍指向 /data/Script.pvf" "$data_path/Script.pvf" "$(readlink "$dest_path/game/Script.pvf")"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
