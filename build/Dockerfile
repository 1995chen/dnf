# Base Image
FROM centos:6.9

MAINTAINER 1995chen

# 定义默认环境变量
ENV PUBLIC_IP=127.0.0.1
ENV DNF_DB_IP=172.20.0.2
ENV DNF_DB_PORT=3306
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass
ENV DNF_DB_ROOT_PASSWORD=88888888
ENV DNF_DB_ALLOW_HOST=172.20.0.%

# 删除旧源
RUN cd /etc/yum.repos.d/ && \
    rm -rf CentOS-Base.repo && \
    sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf
# 添加源
ADD CentOS-Base.repo /etc/yum.repos.d/
# 更新Repo
RUN yum clean all && yum update -y
# 安装基础依赖
RUN yum install -y openssl curl wget vim wget perl gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts
RUN ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6
RUN ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6
# 安装mysql依赖
ADD MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm /tmp
ADD MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm /tmp
RUN rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm
# 编译GeoIP
ADD GeoIP-1.4.8.tgz /home
WORKDIR /home/GeoIP-1.4.8/
RUN chmod 777 configure
RUN ./configure && make && make install
# 添加依赖库
ADD lib.tgz /lib

# 将模板添加到模版目录下[后续容器启动需要先将环境变量替换,再将文件移动到正确位置]
ADD neople /home/template/neople
ADD root /home/template/root

# 启动脚本
ADD docker-entrypoint.sh /

# 放开tmp目录权限
WORKDIR /tmp
RUN chmod -R 777 /tmp

# 该目录用于存放版本文件
RUN mkdir /data

WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
