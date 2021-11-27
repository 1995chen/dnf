# Base Image
FROM 1995chen/centos:6.9

MAINTAINER 1995chen

# 安装mysql依赖
ADD build/Centos6-DNF-Base/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD build/Centos6-DNF-Base/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm /tmp
# 编译GeoIP
ADD build/Centos6/GeoIP-1.4.8.tgz /home
# 添加依赖库
ADD build/Centos6/lib.tgz /lib

# 更新Repo
RUN yum update -y && yum install -y gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts && \
    ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6 && \
    rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && service mysql stop && \
    rm -rf /var/lib/mysql/* && cd /home/GeoIP-1.4.8/ && chmod 777 configure && ./configure && make && make install && yum clean all

# 切换工作目录
WORKDIR /root
