# Base Image
FROM 1995chen/centos:5

MAINTAINER 1995chen

RUN yum install -y wget perl gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ glibc.i686 xulrunner.i386 libXtst.i386 initscripts
ADD GeoIP-1.4.8.tgz /home
ADD neople.tgz /home/neople_bak/
ADD root /root_bak
ADD lib.tgz /lib
ADD mysql.tgz /var/lib/
ADD mysql_install.tgz /tmp
ADD docker-entrypoint.sh /
RUN chmod -R 777 /var/lib/mysql
WORKDIR /tmp
RUN chmod -R 777 /tmp
RUN rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && service mysql stop && \
    rm -rf /tmp/* && mv /var/lib/mysql /var/lib/mysql_bak
WORKDIR /home/GeoIP-1.4.8/
RUN chmod 777 configure
RUN ./configure && make && make install
RUN mkdir /home/neople
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]

# mysql 下载地址
# http://ftp.iij.ad.jp/pub/db/mysql/Downloads/MySQL-5.0/
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
