#!/command/with-contenv bash
# shellcheck shell=bash

template_neople_path="${TEMPLATE_NEOPLE_PATH:-/home/template/neople}"
neople_tmp_path="${NEOPLE_TMP_PATH:-/home/template/neople-tmp}"
neople_path="${NEOPLE_PATH:-/home/neople}"
data_path="${DATA_PATH:-/data}"
template_init_path="${TEMPLATE_INIT_PATH:-/home/template/init}"
dbmw_bin_file="${DBMW_BIN_FILE:-/home/template/init/df_dbmw_r}"

source "${DNF_LIB_PATH:-/home/template/init/lib}/common.sh"

# 初始化密钥对
if [ ! -f "$data_path/privatekey.pem" ]; then
    openssl genrsa -out "$data_path/privatekey.pem" 2048
    openssl rsa -in "$data_path/privatekey.pem" -pubout -out "$data_path/publickey.pem"
    echo "init privatekey.pem and publickey.pem success (newly generated)"
else
    echo "privatekey.pem have already inited, do nothing!"
    # 若私钥已存在但公钥缺失，从私钥派生公钥
    if [ ! -f "$data_path/publickey.pem" ]; then
        openssl rsa -in "$data_path/privatekey.pem" -pubout -out "$data_path/publickey.pem"
        echo "init publickey.pem success (derived from existing privatekey.pem)"
    else
        echo "publickey.pem have already inited, do nothing!"
    fi
fi

# 初始化 DP
mkdir -p "$data_path/dp"
if [ ! -f "$data_path/dp/libhook.so" ]; then
    cp "$template_init_path/libhook.so" "$data_path/dp/"
    echo "init libhook.so success"
else
    echo "libhook.so have already inited, do nothing!"
fi

# 更新时自动备份升级 frida.js
frida_ref_path="$data_path/.frida-template"
mkdir -p "$frida_ref_path"
sync_template_file "$template_init_path/frida.js" "$data_path/frida.js" "$frida_ref_path/frida.js"

# 初始化 monitor_ip 的 get_public_ip.sh 脚本
mkdir -p "$data_path/monitor_ip"
if [ ! -f "$data_path/monitor_ip/get_public_ip.sh" ]; then
    cp "$template_init_path/monitor_ip/get_public_ip.sh" "$data_path/monitor_ip/"
    echo "init get_public_ip.sh success"
else
    echo "get_public_ip.sh have already inited, do nothing!"
fi

# 初始化所有 run 脚本
run_ref_path="$data_path/.run-template"
mkdir -p "$data_path/run" "$run_ref_path"
for fp in "$template_init_path/run"/*.sh; do
    [ -f "$fp" ] || continue
    sh_name=$(basename "$fp")
    sync_template_file "$fp" "$data_path/run/$sh_name" "$run_ref_path/$sh_name"
done

# 初始化定时任务
scheduler_ref_path="$data_path/.scheduler-template"
mkdir -p "$data_path/scheduler" "$scheduler_ref_path"
# 兼容旧路径
if [ -f "$data_path/daily_job/user_daily_script.sh" ] && [ ! -e "$data_path/scheduler/user-script.sh" ]; then
    cp -f "$data_path/daily_job/user_daily_script.sh" "$data_path/scheduler/user-script.sh"
    echo "migrate $data_path/daily_job/user_daily_script.sh -> $data_path/scheduler/user-script.sh"
fi
if [ -f "$data_path/.daily_job-template/user_daily_script.sh" ] && [ ! -e "$scheduler_ref_path/user-script.sh" ]; then
    cp -f "$data_path/.daily_job-template/user_daily_script.sh" "$scheduler_ref_path/user-script.sh"
fi
sync_template_file "$template_init_path/scheduler/user-script.sh" \
    "$data_path/scheduler/user-script.sh" \
    "$scheduler_ref_path/user-script.sh"

rm -rf "$neople_tmp_path"
mkdir -p "$neople_path"
cp -r "$template_neople_path" "$neople_tmp_path"
while IFS= read -r -d '' cfg_file; do
    safe_sed "__GAME_PASSWORD__" "$DNF_DB_GAME_PASSWORD" "$cfg_file"
    safe_sed "__DEC_GAME_PWD__" "$DEC_GAME_PWD" "$cfg_file"
    safe_sed "__SERVER_GROUP_NAME__" "$SERVER_GROUP_NAME" "$cfg_file"
    safe_sed "__SERVER_GROUP_DB__" "$SERVER_GROUP_DB" "$cfg_file"
    safe_sed "__SERVER_GROUP__" "$SERVER_GROUP" "$cfg_file"
    substitute_port_markers "$cfg_file"
done < <(find "$neople_tmp_path" -type f -name "*.cfg" -print0)
while IFS= read -r -d '' tbl_file; do
    safe_sed "__SERVER_GROUP__" "$SERVER_GROUP" "$tbl_file"
    substitute_port_markers "$tbl_file"
done < <(find "$neople_tmp_path" -type f -name "*.tbl" -print0)

secagent_xml="$neople_tmp_path/secsvr/zergsvr/cfg/secagent_config.xml"
[ -f "$secagent_xml" ] && safe_sed "__SECAGENT_CHANNEL_NUM__" "$SECAGENT_CHANNEL_NUM" "$secagent_xml"

svcid_xml="$neople_tmp_path/secsvr/zergsvr/cfg/svcid.xml"
if [ -f "$svcid_xml" ] && [ -n "$ZERGSVR_SELF_TYPE" ] && [ -n "$ZERGSVR_SELF_ID" ] && [ -n "$ZERGSVR_PORT" ]; then
    svcid_rewrite_port "$svcid_xml" "$ZERGSVR_SELF_TYPE" "$ZERGSVR_SELF_ID" "$ZERGSVR_PORT"
fi

# 这里是为了保住日志文件目录，将日志文件挂载到宿主机外，因此采用复制而不是 mv
cp -rf "$neople_tmp_path"/* "$neople_path"
find "$neople_path" -name '*.log' -type f -delete
find "$neople_path" -name '*.pid' -type f -delete
find "$neople_path" -name 'core.*' -type f -delete
chmod 755 -R "$neople_path"
rm -rf "$neople_tmp_path"

ensure_link() {
    [ "$(readlink "$2" 2>/dev/null)" = "$1" ] && return 0
    ln -sfn "$1" "$2"
}

# 初始化 pvf
if [ ! -f "$data_path/Script.pvf" ]; then
    tar -zxf "$template_init_path/Script.tgz" -C "$template_init_path"
    cp "$template_init_path/Script.pvf" "$data_path/Script.pvf"
    echo "init Script.pvf success"
fi
if [ -f "$data_path/Script.pvf" ]; then
    chmod 644 "$data_path/Script.pvf"
    ensure_link "$data_path/Script.pvf" "$neople_path/game/Script.pvf"
else
    echo "ERROR: $data_path/Script.pvf missing after restore" >&2
fi

# 初始化 df_game_r
if [ ! -f "$data_path/df_game_r" ]; then
    cp "$template_init_path/df_game_r" "$data_path/df_game_r"
    echo "init df_game_r success"
fi
if [ -f "$data_path/df_game_r" ]; then
    chmod 755 "$data_path/df_game_r"
    ensure_link "$data_path/df_game_r" "$neople_path/game/df_game_r"
else
    echo "ERROR: $data_path/df_game_r missing after restore" >&2
fi

cp "$data_path/publickey.pem" "$neople_path/game/"

# 初始化 df_dbmw_r
if [ -f "$dbmw_bin_file" ]; then
    for d in dbmw_guild dbmw_mnt dbmw_stat; do
        [ -d "$neople_path/$d" ] || continue
        ensure_link "$dbmw_bin_file" "$neople_path/$d/df_dbmw_r"
    done
else
    echo "ERROR: dbmw binary not found: $dbmw_bin_file" >&2
fi

# 为DP目录赋予权限
chmod 777 -R "$data_path/dp"
