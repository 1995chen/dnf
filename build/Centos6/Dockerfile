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
RUN yum clean all && yum update -y
# 安装基础依赖
RUN yum install -y openssl openssl-devel curl wget vim wget perl gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts
RUN ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6
RUN ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6
# 编译Python2.7[安装supervisor]
ADD build/Centos6/Python-2.7.13.tgz /tmp/
ADD build/Centos6/pip-7.1.0.tar.gz /tmp/
ADD build/Centos6/setuptools-18.0.1.tgz /tmp/
RUN cd /tmp/Python-2.7.13 && ./configure && make install && \
    cd /tmp/setuptools-18.0.1 && python2.7 setup.py install && \
    cd /tmp/pip-7.1.0 && python2.7 setup.py install && \
    pip2.7 install supervisor==3.1.3 && mkdir -p /etc/supervisor/conf.d/
ADD build/Centos6/supervisord.conf /etc/supervisord.conf
# 安装mysql依赖
ADD build/Centos6/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm /tmp
RUN rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && service mysql stop && \
    rm -rf /var/lib/mysql/*
# 编译GeoIP
ADD build/Centos6/GeoIP-1.4.8.tgz /home
WORKDIR /home/GeoIP-1.4.8/
RUN chmod 777 configure
RUN ./configure && make && make install
# 添加依赖库
ADD build/Centos6/lib.tgz /lib
# 切换工作目录
WORKDIR /root
