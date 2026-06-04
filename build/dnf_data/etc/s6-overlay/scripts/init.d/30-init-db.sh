#!/command/with-contenv bash
# shellcheck shell=bash
# 数据库初始化

source "${DNF_LIB_PATH:-/home/template/init/lib}/common.sh"

# 解压init_sql
if [ ! -d "/home/template/init/init_sql" ]; then
    mkdir -p /home/template/init/init_sql/
    tar -zxf /home/template/init/init_sql.tgz -C /home/template/init/init_sql/
    echo "init init_sql success"
else
    echo "init_sql have already inited, do nothing!"
fi

# 初始化本地数据库
run_or_exit "init local db" bash /home/template/init/init-local-db.sh
# 先等主数据库可连接再执行 GRANT, standalone 部署防止与 mysql 启动过程的竞态
run_or_exit "wait for main db" bash /home/template/init/wait-for-mysql.sh \
    "$CUR_MAIN_DB_HOST" "$CUR_MAIN_DB_PORT" "$CUR_MAIN_DB_ROOT_PASSWORD"
# 初始化主数据库
run_or_exit "init main db" bash /home/template/init/init-main-db.sh
# 大区数据库部署在不同 host 或端口时同样需要等待
if [ "$CUR_SG_DB_HOST:$CUR_SG_DB_PORT" != "$CUR_MAIN_DB_HOST:$CUR_MAIN_DB_PORT" ]; then
    run_or_exit "wait for server group db" bash /home/template/init/wait-for-mysql.sh \
        "$CUR_SG_DB_HOST" "$CUR_SG_DB_PORT" "$CUR_SG_DB_ROOT_PASSWORD"
fi
# 初始化大区数据库
run_or_exit "init server group db" bash /home/template/init/init-server-group-db.sh
