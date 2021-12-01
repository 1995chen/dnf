# Base Image
FROM 1995chen/centos:7.9-DNF-Base

MAINTAINER 1995chen

# 定义默认环境变量
ENV PUBLIC_IP=127.0.0.1
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass
ENV DNF_DB_ROOT_PASSWORD=88888888

# 将模板添加到模版目录下[后续容器启动需要先将环境变量替换,再将文件移动到正确位置]
ADD build/Centos7-DNF/neople /home/template/neople
ADD build/Centos7-DNF/root /home/template/root
ADD build/Centos7-DNF/privatekey.pem /home/template/init/
ADD build/Centos7-DNF/publickey.pem /home/template/init/
# 初始化sql脚本
COPY build/Centos7-DNF/init_sql.tgz /home/template/init/
# 初始化版本文件
COPY build/Centos7-DNF/Script.tgz /home/template/init/
# 初始化等级补丁
ADD build/Centos7-DNF/df_game_r /home/template/init/
# 初始化脚本
ADD build/Centos7-DNF/init.sh /home/template/init/
# 启动脚本
ADD build/Centos7-DNF/docker-entrypoint.sh /
# 放开tmp目录权限
WORKDIR /tmp
RUN chmod -R 777 /tmp
# 该目录用于存放版本文件
RUN mkdir /data
# 切换工作目录
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
