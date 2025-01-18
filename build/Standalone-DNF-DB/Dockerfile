# Base Image
FROM 1995chen/centos:5.11.3-DNF-Base

MAINTAINER 1995chen

# 定义默认环境变量
ENV DNF_DB_ROOT_PASSWORD=88888888

# 添加mysql配置
COPY build/dnf_data/my.cnf /etc/
COPY build/Standalone-DNF-DB/docker-entrypoint.sh /
# 切换工作目录
WORKDIR /
CMD ["/bin/bash", "/docker-entrypoint.sh"]
