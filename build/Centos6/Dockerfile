# Base Image
FROM centos:6.9

MAINTAINER 1995chen

# 删除旧源
RUN cd /etc/yum.repos.d/ && \
    rm -rf CentOS-Base.repo && \
    sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf
# 添加源
ADD build/Centos6/CentOS-Base.repo /etc/yum.repos.d/
# 更新Repo
RUN yum clean all && yum update -y && yum install -y openssl openssl-devel curl wget perl vim && \
    yum clean all
# 切换工作目录
WORKDIR /root
