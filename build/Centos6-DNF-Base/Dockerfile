# Base Image
FROM 1995chen/centos:6.9

MAINTAINER 1995chen

# 编译Python2.7[安装supervisor]
ADD build/Centos6-DNF-Base/Python-2.7.13.tgz /tmp/
ADD build/Centos6-DNF-Base/pip-7.1.0.tar.gz /tmp/
ADD build/Centos6-DNF-Base/setuptools-18.0.1.tgz /tmp/
ADD build/Centos6-DNF-Base/supervisord.conf /etc/supervisord.conf
# 安装mysql依赖
ADD build/Centos6-DNF-Base/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm /tmp
# 编译GeoIP
ADD build/Centos6-DNF-Base/GeoIP-1.4.8.tgz /home
# 添加依赖库
ADD build/Centos6-DNF-Base/lib.tgz /lib

# 更新Repo
RUN yum update -y && yum install -y gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts && \
    ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6 && \
    rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && service mysql stop && \
    rm -rf /var/lib/mysql/* && cd /home/GeoIP-1.4.8/ && chmod 777 configure && ./configure && make && make install && yum clean all

# 编译Python2.7.13安装supervisor
RUN cd /tmp/Python-2.7.13 && ./configure && make install && \
    cd /tmp/setuptools-18.0.1 && python2.7 setup.py install && \
    cd /tmp/pip-7.1.0 && python2.7 setup.py install && \
    pip2.7 install supervisor==3.1.3 && mkdir -p /etc/supervisor/conf.d/ && \
    rm -rf /tmp/*

# 切换工作目录
WORKDIR /root
