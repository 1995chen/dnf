#!/command/with-contenv bash
# shellcheck shell=bash
# 解析并构造环境变量，将结果写入 /run/s6/container_environment。

lib_path="${DNF_LIB_PATH:-/home/template/init/lib}"
mysqld_file="${MYSQLD_FILE:-/usr/sbin/mysqld}"
teaencrypt_file="${TEAENCRYPT_FILE:-/TeaEncrypt}"
container_env_path="${CONTAINER_ENV_PATH:-/run/s6/container_environment}"

source "$lib_path/common.sh"
source "$lib_path/tune.sh"

if [ -x "$mysqld_file" ] || [ -x /usr/local/mysql/bin/mysqld ] || [ -x /usr/bin/mysqld ]; then
    tune_resolve_and_export "yes"
else
    tune_resolve_and_export "no"
fi

# 大区对应名称
# 1 : 卡恩, 2 :狄瑞吉, 3 : 希洛克, 4 : 普雷prey, 5 : 凱西亞斯casillas, 6 : 赫爾德hilder
# 大区取决于PVF, PVF不支持则会出现大区灰色
# 目前限制只支持1-6区,其他大区数据库暂时没有内置大区数据库配置
# shellcheck disable=SC2034  # 通过间接展开访问
SERVER_GROUP_NAME_1="cain"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_2="diregie"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_3="siroco"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_4="prey"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_5="casillas"
# shellcheck disable=SC2034
SERVER_GROUP_NAME_6="hilder"

strip_quotes \
    MAIN_BRIDGE_IP SERVER_GROUP_DB SERVER_GROUP \
    MAIN_MYSQL_HOST MAIN_MYSQL_PORT MAIN_MYSQL_ROOT_PASSWORD MAIN_MYSQL_GAME_ALLOW_IP \
    MYSQL_HOST MYSQL_PORT MYSQL_GAME_ALLOW_IP \
    AUTO_PUBLIC_IP PUBLIC_IP \
    GM_ACCOUNT GM_PASSWORD GM_CONNECT_KEY GM_LANDER_VERSION \
    DNF_DB_ROOT_PASSWORD DNF_DB_GAME_PASSWORD \
    OPEN_CHANNEL \
    DDNS_ENABLE DDNS_DOMAIN DDNS_INTERVAL \
    NB_SETUP_KEY NB_MANAGEMENT_URL \
    DB_USER DB_NAME \
    GATE_AES_KEY GATE_BIND_ADDRESS GATE_RUST_LOG RSA_PRIVATE_KEY_PATH \
    INITIAL_CERA INITIAL_CERA_POINT \
    GATE_TLS_CERT_PATH GATE_TLS_KEY_PATH GATE_TLS_BIND_ADDRESS GATE_TLS_ONLY \
    GAME_SERVER_IP

strip_quotes CLIENT_POOL_SIZE

# 校验用户设置的大区
SERVER_GROUP_NAME_VAR="SERVER_GROUP_NAME_$SERVER_GROUP"
if [ "$SERVER_GROUP" -ge 1 ] && [ "$SERVER_GROUP" -le 6 ]; then
    SERVER_GROUP_NAME=${!SERVER_GROUP_NAME_VAR}
    echo "server group is $SERVER_GROUP, server group name is $SERVER_GROUP_NAME"
else
    echo "invalid server group: $SERVER_GROUP"
    exit 1
fi
# 大区使用的数据库[不同大区可以共用数据库]
if [ -z "$SERVER_GROUP_DB" ]; then
    SERVER_GROUP_DB=$SERVER_GROUP_NAME
fi

# 主数据库优先使用 MAIN_MYSQL_*, MYSQL_* 作为 fallback
CUR_MAIN_DB_HOST=${MAIN_MYSQL_HOST:-$MYSQL_HOST}
CUR_MAIN_DB_PORT=${MAIN_MYSQL_PORT:-$MYSQL_PORT}
CUR_MAIN_DB_ROOT_PASSWORD=${MAIN_MYSQL_ROOT_PASSWORD:-$DNF_DB_ROOT_PASSWORD}
CUR_MAIN_DB_GAME_ALLOW_IP=${MAIN_MYSQL_GAME_ALLOW_IP:-$MYSQL_GAME_ALLOW_IP}
if [ -z "$CUR_MAIN_DB_HOST" ] && [ -z "$CUR_MAIN_DB_PORT" ]; then
    if [ ! -x "$mysqld_file" ]; then
        echo "ERROR: no local MySQL server and no external MySQL configured."
        echo "Set MYSQL_HOST and MYSQL_PORT (or MAIN_MYSQL_HOST and MAIN_MYSQL_PORT)."
        exit 1
    fi
    CUR_MAIN_DB_HOST=127.0.0.1
    CUR_MAIN_DB_PORT=4000
    # shellcheck disable=SC2034
    CUR_MAIN_DB_ROOT_PASSWORD=$DNF_DB_ROOT_PASSWORD
    CUR_MAIN_DB_GAME_ALLOW_IP=127.0.0.1
fi
echo "main db: $CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT allow ip $CUR_MAIN_DB_GAME_ALLOW_IP"

# 大区数据库优先使用 MYSQL_*, MAIN_MYSQL_* 作为 fallback
CUR_SG_DB_HOST=${MYSQL_HOST:-$MAIN_MYSQL_HOST}
CUR_SG_DB_PORT=${MYSQL_PORT:-$MAIN_MYSQL_PORT}
# shellcheck disable=SC2034
CUR_SG_DB_ROOT_PASSWORD=$DNF_DB_ROOT_PASSWORD
CUR_SG_DB_GAME_ALLOW_IP=${MYSQL_GAME_ALLOW_IP:-$MAIN_MYSQL_GAME_ALLOW_IP}
if [ -z "$CUR_SG_DB_HOST" ] && [ -z "$CUR_SG_DB_PORT" ]; then
    if [ ! -x "$mysqld_file" ]; then
        echo "ERROR: no local MySQL server and no external MySQL configured."
        echo "Set MYSQL_HOST and MYSQL_PORT (or MAIN_MYSQL_HOST and MAIN_MYSQL_PORT)."
        exit 1
    fi
    CUR_SG_DB_HOST=127.0.0.1
    CUR_SG_DB_PORT=4000
    CUR_SG_DB_GAME_ALLOW_IP=127.0.0.1
fi
echo "server group db: $CUR_SG_DB_HOST:$CUR_SG_DB_PORT allow ip $CUR_SG_DB_GAME_ALLOW_IP"
echo "will use server group: $SERVER_GROUP_NAME"

# 加密GAME密码
chmod 1777 /tmp
chmod +x "$teaencrypt_file"
DNF_DB_GAME_PASSWORD=${DNF_DB_GAME_PASSWORD:0:8}
DEC_GAME_PWD=$("$teaencrypt_file" "$DNF_DB_GAME_PASSWORD")
echo "game pwd key: ${DEC_GAME_PWD:0:4}..."

# 清风版本需要额外的数据库用户
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF:-supergod,chhappy,cash}"
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF//\'/}"
DNF_DB_USER_EXTENDED_QF="${DNF_DB_USER_EXTENDED_QF//\"/}"

# 写入 container_environment，后续 hook 和服务通过 with-contenv 读取
mkdir -p "$container_env_path"
write_env() {
    local var="$1"
    [ "${!var+set}" = "set" ] && printf '%s' "${!var}" >"$container_env_path/$var"
    return 0
}
for v in MAIN_BRIDGE_IP SERVER_GROUP SERVER_GROUP_NAME SERVER_GROUP_DB \
    CUR_MAIN_DB_HOST CUR_MAIN_DB_PORT CUR_MAIN_DB_ROOT_PASSWORD CUR_MAIN_DB_GAME_ALLOW_IP \
    CUR_SG_DB_HOST CUR_SG_DB_PORT CUR_SG_DB_ROOT_PASSWORD CUR_SG_DB_GAME_ALLOW_IP \
    DNF_DB_GAME_PASSWORD DEC_GAME_PWD DNF_DB_USER_EXTENDED_QF \
    MALLOC_CONF MALLOC_CONF_32 MALLOC_CONF_64 \
    AUTO_PUBLIC_IP PUBLIC_IP \
    DDNS_ENABLE DDNS_DOMAIN DDNS_INTERVAL \
    NB_SETUP_KEY NB_MANAGEMENT_URL \
    TS_AUTH_KEY TS_LOGIN_SERVER \
    DB_USER DB_NAME GAME_SERVER_IP RSA_PRIVATE_KEY_PATH \
    INITIAL_CERA INITIAL_CERA_POINT \
    GATE_AES_KEY GATE_BIND_ADDRESS GATE_RUST_LOG \
    GATE_TLS_BIND_ADDRESS GATE_TLS_ONLY GATE_TLS_CERT_PATH GATE_TLS_KEY_PATH; do
    write_env "$v"
done
