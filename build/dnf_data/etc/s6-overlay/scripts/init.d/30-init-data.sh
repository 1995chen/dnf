#!/command/with-contenv bash
# shellcheck shell=bash
# 初始化数据库、生成密钥，创建 /home/neople/

template_neople_path="${TEMPLATE_NEOPLE_PATH:-/home/template/neople}"
neople_tmp_path="${NEOPLE_TMP_PATH:-/home/template/neople-tmp}"
neople_path="${NEOPLE_PATH:-/home/neople}"
data_path="${DATA_PATH:-/data}"
init_script_file="${INIT_SCRIPT_FILE:-/home/template/init/init.sh}"
dbmw_bin_file="${DBMW_BIN_FILE:-/home/template/init/df_dbmw_r}"

source "${DNF_LIB_PATH:-/home/template/init/lib}/common.sh"

if ! bash "$init_script_file"; then
    echo "init failed" >&2
    exit 1
fi

rm -rf "$neople_tmp_path"
mkdir -p "$neople_path"
cp -r "$template_neople_path" "$neople_tmp_path"
while IFS= read -r -d '' cfg_file; do
    safe_sed "GAME_PASSWORD" "$DNF_DB_GAME_PASSWORD" "$cfg_file"
    safe_sed "DEC_GAME_PWD" "$DEC_GAME_PWD" "$cfg_file"
    safe_sed "SERVER_GROUP_NAME" "$SERVER_GROUP_NAME" "$cfg_file"
    safe_sed "SERVER_GROUP_DB" "$SERVER_GROUP_DB" "$cfg_file"
    safe_sed "SERVER_GROUP" "$SERVER_GROUP" "$cfg_file"
done < <(find "$neople_tmp_path" -type f -name "*.cfg" -print0)
while IFS= read -r -d '' tbl_file; do
    safe_sed "SERVER_GROUP" "$SERVER_GROUP" "$tbl_file"
done < <(find "$neople_tmp_path" -type f -name "*.tbl" -print0)

# 这里是为了保住日志文件目录，将日志文件挂载到宿主机外，因此采用复制而不是 mv
cp -rf "$neople_tmp_path"/* "$neople_path"
find "$neople_path" -name '*.log' -type f -delete
find "$neople_path" -name '*.pid' -type f -delete
find "$neople_path" -name 'core.*' -type f -delete
chmod 755 -R "$neople_path"
rm -rf "$neople_tmp_path"

# 复制版本文件
cp "$data_path/Script.pvf" "$neople_path/game/Script.pvf"
chmod 644 "$neople_path/game/Script.pvf"
cp "$data_path/df_game_r" "$neople_path/game/df_game_r"
chmod 755 "$neople_path/game/df_game_r"
cp "$data_path/publickey.pem" "$neople_path/game/"

# 复制 df_dbmw_r
if [ -f "$dbmw_bin_file" ]; then
    for d in dbmw_guild dbmw_mnt dbmw_stat; do
        [ -d "$neople_path/$d" ] || continue
        cp "$dbmw_bin_file" "$neople_path/$d/df_dbmw_r"
        chmod 755 "$neople_path/$d/df_dbmw_r"
    done
else
    echo "ERROR: dbmw binary not found: $dbmw_bin_file" >&2
fi

# 为DP目录赋予权限
chmod 777 -R "$data_path/dp"
