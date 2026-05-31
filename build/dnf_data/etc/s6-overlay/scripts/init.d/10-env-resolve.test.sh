#!/bin/bash
# 10-env-resolve.sh 环境变量解析测试脚本

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
HOOK="${SCRIPT_PATH}/10-env-resolve.sh"
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

main_proxy_cfg="$WORK/main_proxy.cfg"
printf 'master_db_ip = 127.0.0.1\nmaster_db_port = 3307\n' >"$main_proxy_cfg"
sg_proxy_cfg="$WORK/sg_proxy.cfg"
printf 'game_db_ip = 127.0.0.1\ngame_db_port = 3306\nauction_db_port = 3306\n' >"$sg_proxy_cfg"

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
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    MAIN_PROXY_CFG="$main_proxy_cfg" SG_PROXY_CFG="$sg_proxy_cfg"
rc=$?
chk "主库/大区库一体化: 退出码" 0 "$rc"
chk "主库/大区库一体化: 默认主库 host" "127.0.0.1" "$(getenv CUR_MAIN_DB_HOST)"
chk "主库/大区库一体化: 默认主库 port" "4000" "$(getenv CUR_MAIN_DB_PORT)"
chk "主库/大区库一体化: 主库密码" "secret" "$(getenv CUR_MAIN_DB_ROOT_PASSWORD)"
chk "主库/大区库一体化: 默认 allow_ip" "127.0.0.1" "$(getenv CUR_MAIN_DB_GAME_ALLOW_IP)"
chk "主库/大区库一体化: 大区库默认 host" "127.0.0.1" "$(getenv CUR_SG_DB_HOST)"
chk "主库/大区库一体化: 主库 proxy 监听端口" "3307" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "主库/大区库一体化: 大区库 proxy 监听端口" "3306" "$(getenv CUR_SG_DB_PROXY_PORT)"

# proxy 监听端口从 cfg 解析，改 cfg 端口后解析结果发生变化
printf 'master_db_port = 9999\n' >"$WORK/alt_main.cfg"
printf 'game_db_port = 8888\n' >"$WORK/alt_sg.cfg"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    MAIN_PROXY_CFG="$WORK/alt_main.cfg" SG_PROXY_CFG="$WORK/alt_sg.cfg"
chk "proxy 端口随 cfg 变化: 主库 master_db_port" "9999" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "proxy 端口随 cfg 变化: 大区库 game_db_port" "8888" "$(getenv CUR_SG_DB_PROXY_PORT)"

# 主库已配置但 cfg 无对应配置项: proxy 端口为空, 显示告警信息
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    MAIN_PROXY_CFG="$WORK/no-such.cfg" SG_PROXY_CFG="$sg_proxy_cfg"
chk "cfg 缺失: 主库 proxy 端口为空" "" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "cfg 缺失: 打印 WARN 到 stderr" yes "$(grep -q 'WARN.*master_db_port' "$WORK/last.err" && echo yes || echo no)"
chk "cfg 缺失: 不影响大区库 cfg 解析" "3306" "$(getenv CUR_SG_DB_PROXY_PORT)"

# 仅配置 host 缺 port: 即使 cfg 有端口也不启动 proxy
run_resolve "$mysqld_absent" SERVER_GROUP=3 MYSQL_HOST=only.host DNF_DB_ROOT_PASSWORD=secret \
    MAIN_PROXY_CFG="$main_proxy_cfg" SG_PROXY_CFG="$sg_proxy_cfg"
chk "仅配置 host 缺 port: 退出码" 0 "$?"
chk "仅配置 host 缺 port: 主库 proxy 端口为空" "" "$(getenv CUR_MAIN_DB_PROXY_PORT)"
chk "仅配置 host 缺 port: 大区库 proxy 端口为空" "" "$(getenv CUR_SG_DB_PROXY_PORT)"

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

# DNF_DB_USER_EXTENDED_QF 默认值与引号处理
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret
chk "清风版本特有的数据库用户" "supergod,chhappy,cash" "$(getenv DNF_DB_USER_EXTENDED_QF)"
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret \
    DNF_DB_USER_EXTENDED_QF="'a,b'"
chk "自定义清风数据库用户引号处理" "a,b" "$(getenv DNF_DB_USER_EXTENDED_QF)"

# write_env 语义: 手动设置的空字符串写空文件, 未设置则不写
run_resolve "$mysqld_present" SERVER_GROUP=3 DNF_DB_ROOT_PASSWORD=secret TS_AUTH_KEY=
chk "write_env 语义: 空字符串写空文件" yes "$(exists "$envdir/TS_AUTH_KEY")"
chk "write_env 语义: 文件内容为空" "" "$(getenv TS_AUTH_KEY)"
chk "write_env 语义: 空变量不写文件" no "$(exists "$envdir/TS_LOGIN_SERVER")"

echo "pass=$pass failed=$failed"
[ "$failed" -eq 0 ]
