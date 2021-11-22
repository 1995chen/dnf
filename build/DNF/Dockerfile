# Base Image
FROM 1995chen/centos:6.9

MAINTAINER 1995chen

# 定义默认环境变量
ENV PUBLIC_IP=127.0.0.1
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass
ENV DNF_DB_ROOT_PASSWORD=88888888

# 添加配置
ADD build/DNF/dnf.conf /etc/supervisor/conf.d/
# 将模板添加到模版目录下[后续容器启动需要先将环境变量替换,再将文件移动到正确位置]
ADD build/DNF/neople /home/template/neople
ADD build/DNF/root /home/template/root
# 初始化sql脚本
ADD build/DNF/init_sql.tgz /home/template/init/
# 初始化版本文件
ADD build/DNF/Script.tgz /home/template/init/
# 初始化等级补丁
ADD build/DNF/df_game_r /home/template/init/
# 初始化脚本
ADD build/DNF/init.sh /home/template/init/
# 启动脚本
ADD build/DNF/docker-entrypoint.sh /
# 放开tmp目录权限
WORKDIR /tmp
RUN chmod -R 777 /tmp
# 该目录用于存放版本文件
RUN mkdir /data
# 切换工作目录
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
