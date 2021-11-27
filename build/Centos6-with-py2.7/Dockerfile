# Base Image
FROM 1995chen/centos:6.9

MAINTAINER 1995chen

# 编译Python2.7[安装supervisor]
ADD build/Centos6-with-py2.7/Python-2.7.13.tgz /tmp/
ADD build/Centos6-with-py2.7/pip-7.1.0.tar.gz /tmp/
ADD build/Centos6-with-py2.7/setuptools-18.0.1.tgz /tmp/
ADD build/Centos6-with-py2.7/supervisord.conf /etc/supervisord.conf

# 更新Repo
RUN yum update -y && yum install -y gcc gcc-c++ make zlib-devel initscripts && \
    cd /tmp/Python-2.7.13 && ./configure && make install && \
    cd /tmp/setuptools-18.0.1 && python2.7 setup.py install && \
    cd /tmp/pip-7.1.0 && python2.7 setup.py install && \
    pip2.7 install supervisor==3.1.3 && mkdir -p /etc/supervisor/conf.d/ && \
    yum clean all

# 切换工作目录
WORKDIR /root
