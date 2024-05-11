# Base Image
FROM centos:7.9.2009

MAINTAINER 1995chen

# 删除旧源
RUN cd /etc/yum.repos.d/ && \
    rm -rf CentOS-Base.repo && \
    sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf
# 添加源
ADD build/Centos7/CentOS-Base.repo /etc/yum.repos.d/
# 更新Repo
RUN yum clean all && yum update -y && yum install -y psmisc openssl openssl-devel curl wget perl vim iptables \
    gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts bind-utils && \
    ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6 && \
    yum clean all
# 切换工作目录
WORKDIR /root
