# Base Image
FROM centos:6.9

MAINTAINER 1995chen

# 定义默认环境变量
ENV PUBLIC_IP=127.0.0.1
ENV DNF_DB_IP=dnf-mysql
ENV DNF_DB_PORT=3306
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass

# 删除旧源
RUN cd /etc/yum.repos.d/ && \
    rm -rf CentOS-Base.repo && \
    sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf
# 添加源
ADD CentOS-Base.repo /etc/yum.repos.d/
# 更新Repo
RUN yum clean all && yum update -y
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

# 关闭宿主机防火墙
# Centos5-6
# service iptables stop
# chkconfig iptables off
# Centos7
# systemctl disable firewalld
# systemctl stop firewalld
# systemctl disable firewalld.service
# systemctl stop firewalld.service
# 在宿主机添加swap
# /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
# mkswap /var/swap.1
# swapon /var/swap.1
# sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
