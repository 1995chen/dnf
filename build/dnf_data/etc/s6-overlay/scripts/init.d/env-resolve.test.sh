#!/bin/bash
# env-resolve.sh 环境变量解析测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/env-resolve.sh"
LIB_PATH=$(cd -- "${SCRIPT_PATH}/../../../../home/template/init/lib" &>/dev/null && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

tea_file="$WORK/TeaEncrypt"
cat >"$tea_file" <<'EOF'
#!/bin/bash
printf 'ENC:%s' "$1"
EOF
chmod +x "$tea_file"

mysqld_present="$WORK/mysqld-present"
printf '#!/bin/bash\n' >"$mysqld_present"
chmod +x "$mysqld_present"
mysqld_absent="$WORK/no-such-mysqld"

zerg_dir="$WORK/zergcfg"
mkdir -p "$zerg_dir"
printf '<zerg_config>\n\t<self_cfg>\n\t\t<self_svr_info>\n\t\t\t<svr_type>30</svr_type>\n\t\t\t<svr_id>570011</svr_id>\n\t\t</self_svr_info>\n\t</self_cfg>\n</zerg_config>\n' >"$zerg_dir/zergsvrd.xml"
printf '<svcid_config>\n\t<service_info_>\n\t\t<svr_type_> 31 </svr_type_>\n\t\t<svr_id_> 570001 </svr_id_>\n\t\t<svr_port_> 9000 </svr_port_>\n\t</service_info_>\n\t<service_info_>\n\t\t<svr_type_> 30 </svr_type_>\n\t\t<svr_id_> 570011 </svr_id_>\n\t\t<svr_port_> 9000 </svr_port_>\n\t</service_info_>\n</svcid_config>\n' >"$zerg_dir/svcid.xml"

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

# 用法: run_resolve <mysqld_file> VAR=val ...
envdir=""
run_resolve() {
    local mysqld="$1"
    shift
    envdir=$(mktemp -d "$WORK/env.XXXXXX")
    env -i PATH="$PATH" \
        DNF_LIB_PATH="$LIB_PATH" \
        MYSQLD_FILE="$mysqld" \
        TEAENCRYPT_FILE="$tea_file" \
        CONTAINER_ENV_PATH="$envdir" \
        "$@" \
        bash "$HOOK" >/dev/null 2>"$WORK/last.err"
}
getenv() { cat "$envdir/$1" 2>/dev/null; }

# 外部数据库: 只设 MYSQL_* 时, 密码默认使用 DNF_DB_ROOT_PASSWORD
run_resolve "$mysqld_absent" SERVER_GROUP=3 \
    MYSQL_HOST=db.example MYSQL_PORT=3306 \
    MYSQL_GAME_ALLOW_IP=1.2.3.4 DNF_DB_ROOT_PASSWORD=secret
rc=$?
chk "外部数据库: 退出码" 0 "$rc"
chk "外部数据库: 主库 host 用 MYSQL_HOST" "db.example" "$(getenv CUR_MAIN_DB_HOST)"
chk "外部数据库: 主库 port" "3306" "$(getenv CUR_MAIN_DB_PORT)"
chk "外部数据库: 密码默认用 DNF_DB_ROOT_PASSWORD" "secret" "$(getenv CUR_MAIN_DB_ROOT_PASSWORD)"
chk "外部数据库: 主库 allow_ip" "1.2.3.4" "$(getenv CUR_MAIN_DB_GAME_ALLOW_IP)"
chk "外部数据库: 大区库 host 使用 MYSQL_HOST" "db.example" "$(getenv CUR_SG_DB_HOST)"

# 主库/大区库分离: 主库优先 MAIN_MYSQL_*, 大区库优先 MYSQL_*
run_resolve "$mysqld_absent" SERVER_GROUP=3 \
    MAIN_MYSQL_HOST=main.db MAIN_MYSQL_PORT=3307 MAIN_MYSQL_ROOT_PASSWORD=mainpw \
    MYSQL_HOST=sg.db MYSQL_PORT=3306 DNF_DB_ROOT_PASSWORD=secret
rc=$?
chk "主库/大区库分离: 退出码" 0 "$rc"
chk "主库/大区库分离: 主库用 MAIN_MYSQL_HOST" "main.db" "$(getenv CUR_MAIN_DB_HOST)"
chk "主库/大区库分离: 主库 port" "3307" "$(getenv CUR_MAIN_DB_PORT)"
chk "主库/大区库分离: 主库密码用 MAIN_MYSQL_ROOT_PASSWORD" "mainpw" "$(getenv CUR_MAIN_DB_ROOT_PASSWORD)"
chk "主库/大区库分离: 大区库用 MYSQL_HOST" "sg.db" "$(getenv CUR_SG_DB_HOST)"
chk "主库/大区库分离: 大区库 port" "3306" "$(getenv CUR_SG_DB_PORT)"

# 主库/大区库一体化: 无 host/port 且本地 mysqld 存在时，默认使用 127.0.0.1:4000
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
rc=$?
chk "主库/大区库一体化: 退出码" 0 "$rc"
chk "主库/大区库一体化: 默认主库 host" "127.0.0.1" "$(getenv CUR_MAIN_DB_HOST)"
chk "主库/大区库一体化: 默认主库 port" "4000" "$(getenv CUR_MAIN_DB_PORT)"
chk "主库/大区库一体化: 主库密码" "secret" "$(getenv CUR_MAIN_DB_ROOT_PASSWORD)"
chk "主库/大区库一体化: 默认 allow_ip" "127.0.0.1" "$(getenv CUR_MAIN_DB_GAME_ALLOW_IP)"
chk "主库/大区库一体化: 大区库默认 host" "127.0.0.1" "$(getenv CUR_SG_DB_HOST)"
chk "主库/大区库一体化: 主库 proxy 监听端口默认 3307" "3307" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "主库/大区库一体化: 大区库 proxy 监听端口默认 3306" "3306" "$(getenv CUR_SG_DB_PROXY_PORT)"

# 各服务端组件默认端口，不同大区的 relay 端口由 SERVER_GROUP 拼接
chk "框架端口: auction 默认 30803" "30803" "$(getenv AUCTION_TCP_PORT)"
chk "框架端口: channel 默认 7001" "7001" "$(getenv CHANNEL_TCP_PORT)"
chk "框架端口: manager 默认 40403" "40403" "$(getenv MANAGER_TCP_PORT)"
chk "框架端口: relay 随大区 7SG00" "7300" "$(getenv RELAY_TCP_PORT)"
chk "框架端口: coserver 默认 30703" "30703" "$(getenv COSERVER_UDP_PORT)"
chk "框架端口: statics 默认 30503" "30503" "$(getenv STATICS_UDP_PORT)"

# 默认端口可被环境变量覆盖
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    MAIN_DB_PROXY_PORT=19999 SG_DB_PROXY_PORT=18888 AUCTION_TCP_PORT=12345
chk "自定义端口: 主库 proxy 端口" "19999" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "自定义端口: 大区库 proxy 端口" "18888" "$(getenv CUR_SG_DB_PROXY_PORT)"
chk "自定义端口: auction 端口" "12345" "$(getenv AUCTION_TCP_PORT)"

# 仅配置 host 缺 port: 该库视为未配置, proxy 监听端口为空, 不启动
run_resolve "$mysqld_absent" SERVER_GROUP=3 MYSQL_HOST=only.host DNF_DB_ROOT_PASSWORD=secret
chk "仅配置 host 缺 port: 退出码" 0 "$?"
chk "仅配置 host 缺 port: 主库 proxy 端口为空" "" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "仅配置 host 缺 port: 大区库 proxy 端口为空" "" "$(getenv CUR_SG_DB_PROXY_PORT)"

# secagent 频道数: 未设置 OPEN_CHANNEL 时默认为 12
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "secagent 频道数: 未设置 OPEN_CHANNEL 时默认 12" "12" "$(getenv SECAGENT_CHANNEL_NUM)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret OPEN_CHANNEL=11,52
chk "secagent 频道数: 2 频道为 2" "2" "$(getenv SECAGENT_CHANNEL_NUM)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret OPEN_CHANNEL=11-15
chk "secagent 频道数: 11-15 取 5" "5" "$(getenv SECAGENT_CHANNEL_NUM)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret OPEN_CHANNEL="'1,8,40,11'"
chk "secagent 频道数: 忽略非法频道" "2" "$(getenv SECAGENT_CHANNEL_NUM)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret OPEN_CHANNEL=11,52 SECAGENT_CHANNEL_NUM=7
chk "secagent 频道数可覆盖" "7" "$(getenv SECAGENT_CHANNEL_NUM)"

# zergsvr 监听端口: 解析 zergsvrd self 取 (type,id), 再查 svcid 端口作为默认值
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret ZERGSVR_CFG_DIR="$zerg_dir"
chk "zergsvr self type" "30" "$(getenv ZERGSVR_SELF_TYPE)"
chk "zergsvr self id" "570011" "$(getenv ZERGSVR_SELF_ID)"
chk "zergsvr 端口默认从 svcid 解析" "9000" "$(getenv ZERGSVR_PORT)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    ZERGSVR_CFG_DIR="$zerg_dir" ZERGSVR_PORT=9999
chk "zergsvr 端口可覆盖" "9999" "$(getenv ZERGSVR_PORT)"

# 无本地 mysqld -> 退出 1
run_resolve "$mysqld_absent" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "无本地mysqld退出码为1" 1 "$?"

# SERVER_GROUP 校验
run_resolve "$mysqld_present" SERVER_GROUP=7 DNF_DB_ROOT_PASSWORD=secret
chk "SERVER_GROUP 校验: SERVER_GROUP=7 退出码为1" 1 "$?"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
rc=$?
chk "SERVER_GROUP 校验: SERVER_GROUP=3 退出0" 0 "$rc"
chk "SERVER_GROUP 校验: SERVER_GROUP_NAME=siroco" "siroco" "$(getenv SERVER_GROUP_NAME)"

# SERVER_GROUP_DB 为空时取 SERVER_GROUP_NAME, 不为空则保留
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "SERVER_GROUP_DB 为空则为 siroco" "siroco" "$(getenv SERVER_GROUP_DB)"
run_resolve "$mysqld_present" SERVER_GROUP=3 SERVER_GROUP_DB=customdb DNF_DB_ROOT_PASSWORD=secret
chk "SERVER_GROUP_DB 不为空则保留" "customdb" "$(getenv SERVER_GROUP_DB)"

# GAME 密码截断到 8 位并加密
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    DNF_DB_GAME_PASSWORD=longpassword123
rc=$?
chk "GAME 密码截断8位" "longpass" "$(getenv DNF_DB_GAME_PASSWORD)"
chk "DEC_GAME_PWD 为加密结果" "ENC:longpass" "$(getenv DEC_GAME_PWD)"

# strip_quotes 去除带引号输入
run_resolve "$mysqld_present" SERVER_GROUP="'3'" DNF_DB_ROOT_PASSWORD=secret
rc=$?
chk "strip_quotes: 带引号 SERVER_GROUP 退出码为0" 0 "$rc"
chk "strip_quotes: 去除引号后 name=siroco" "siroco" "$(getenv SERVER_GROUP_NAME)"
chk "strip_quotes: SERVER_GROUP 写入为3" "3" "$(getenv SERVER_GROUP)"

# DNF_DB_USER_EXTENDED 默认值与引号处理
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "扩展数据库用户默认为空" "" "$(getenv DNF_DB_USER_EXTENDED)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    DNF_DB_USER_EXTENDED="'a,b'"
chk "扩展数据库用户引号处理" "a,b" "$(getenv DNF_DB_USER_EXTENDED)"

# write_env 语义: 手动设置的空字符串写空文件, 未设置则不写
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret TS_AUTH_KEY=
chk "write_env 语义: 空字符串写空文件" yes "$(exists "$envdir/TS_AUTH_KEY")"
chk "write_env 语义: 文件内容为空" "" "$(getenv TS_AUTH_KEY)"
chk "write_env 语义: 空变量不写文件" no "$(exists "$envdir/TS_LOGIN_SERVER")"

# CLIENT_POOL_SIZE
is_pos_int() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ] && echo yes || echo no; }
# 未设置时 tune 按性能自动计算并写入
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "CLIENT_POOL_SIZE: 自动计算值已写入" yes "$(exists "$envdir/CLIENT_POOL_SIZE")"
chk "CLIENT_POOL_SIZE: 自动计算结果为正整数" yes "$(is_pos_int "$(getenv CLIENT_POOL_SIZE)")"
# 指定性能配置时使用其配置计算值
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret TUNE_PROFILE=xlarge
chk "CLIENT_POOL_SIZE: xlarge 配置为 1000" "1000" "$(getenv CLIENT_POOL_SIZE)"
# 自定义 CLIENT_POOL_SIZE
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret CLIENT_POOL_SIZE=300
chk "CLIENT_POOL_SIZE: 自定义的值正常传递" "300" "$(getenv CLIENT_POOL_SIZE)"
# strip_quotes 处理带引号的值
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret CLIENT_POOL_SIZE="'600'"
chk "CLIENT_POOL_SIZE: 去除引号后写入" "600" "$(getenv CLIENT_POOL_SIZE)"
# 显式清空后为空字符串
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret CLIENT_POOL_SIZE=
chk "CLIENT_POOL_SIZE: 显式清空写空文件" yes "$(exists "$envdir/CLIENT_POOL_SIZE")"
chk "CLIENT_POOL_SIZE: 清空后内容为空" "" "$(getenv CLIENT_POOL_SIZE)"

# DNF_DB_ROOT_PASSWORD
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=rootpw
chk "DNF_DB_ROOT_PASSWORD: 写入 container_environment" yes "$(exists "$envdir/DNF_DB_ROOT_PASSWORD")"
chk "DNF_DB_ROOT_PASSWORD: 自定义的值正常传递" "rootpw" "$(getenv DNF_DB_ROOT_PASSWORD)"
# strip_quotes 处理带引号的值
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD="'quotedpw'"
chk "DNF_DB_ROOT_PASSWORD: 去除引号后写入" "quotedpw" "$(getenv DNF_DB_ROOT_PASSWORD)"
chk "DNF_DB_ROOT_PASSWORD: 与 CUR_MAIN_DB_ROOT_PASSWORD 一致" "$(getenv CUR_MAIN_DB_ROOT_PASSWORD)" "$(getenv DNF_DB_ROOT_PASSWORD)"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
