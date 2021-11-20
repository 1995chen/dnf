# Base Image
FROM 1995chen/centos:5

MAINTAINER 1995chen

# 定义默认环境变量
ENV PUBLIC_IP=127.0.0.1
ENV DNF_DB_IP=172.20.0.2
ENV DNF_DB_PORT=3306
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass
ENV DNF_DB_ROOT_PASSWORD=88888888
ENV DNF_DB_ALLOW_HOST=172.20.0.%

# 安装基础依赖
RUN yum install -y mysql-community-client.x86_64 wget perl gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ glibc.i686 xulrunner.i386 libXtst.i386 initscripts
ADD GeoIP-1.4.8.tgz /home
# 编译
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
