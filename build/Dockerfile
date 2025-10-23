FROM centos:7.9.2009

LABEL AUTHOR 1995chen

ENV TZ=Asia/Shanghai
# 安装环境
RUN cd /etc/yum.repos.d/ && rm -rf * && sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf && \
    # 添加源
    curl -o CentOS-Base.repo https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos7/CentOS-Base.repo && \
    # 更新软件
    yum clean all && yum update -y && yum install -y psmisc openssl openssl-devel curl wget perl vim iptables \
    gcc gcc-c++ make zlib-devel libc.so.6 libstdc++ libstdc++.so.6 glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts bind-utils nc && \
    ln -sf /usr/lib64/libssl.so.10 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6 && \
    # 下载软件
    cd /tmp && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/socat-1.7.4.3.tar.gz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/Python-2.7.13.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/setuptools-18.0.1.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/pip-7.1.0.tar.gz && \
    wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.5.27-1.el6.x86_64.rpm-bundle.tar && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/GeoIP-1.4.8.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/lib.tgz && \
    # 解压
    tar -zxvf socat-1.7.4.3.tar.gz && \
    tar -zxvf Python-2.7.13.tgz && \
    tar -zxvf setuptools-18.0.1.tgz && \
    tar -zxvf pip-7.1.0.tar.gz && \
    tar -xvf mysql-5.5.27-1.el6.x86_64.rpm-bundle.tar && \
    tar -zxvf GeoIP-1.4.8.tgz && \
    tar -zxvf lib.tgz && \
    # 移动so文件
    mv /tmp/*.so /lib/ &&  mv /tmp/*.so.1 /lib/ && \
    # 安装socat
    cd /tmp/socat-1.7.4.3 && ./configure --disable-fips make && make install && \
    # 编译python2.7 supervisor
    cd /tmp/Python-2.7.13 && ./configure && make install && \
    cd /tmp/setuptools-18.0.1 && python2.7 setup.py install && \
    cd /tmp/pip-7.1.0 && python2.7 setup.py install && \
    pip2.7 install supervisor==3.1.3 && \ 
    # 安装mysql 5.5.27
    rpm -ivh MySQL-server-5.5.27-1.el6.x86_64.rpm && \
    rpm -ivh MySQL-client-5.5.27-1.el6.x86_64.rpm && \
    rpm -ivh MySQL-devel-5.5.27-1.el6.x86_64.rpm && \
    rpm -ivh MySQL-shared-5.5.27-1.el6.x86_64.rpm && \
    service mysql stop && rm -rf /var/lib/mysql/* && \
    # 编译GeoIP
    cd /tmp/GeoIP-1.4.8/ && chmod 777 configure && ./configure && make && make install && \
    # 设置时区
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    # 清理
    yum clean all && \
    rm -rf /tmp/*

# 定义默认环境变量

# 是否连接远程bridge
ENV MAIN_BRIDGE_IP='127.0.0.1'
ENV SERVER_GROUP_DB='cain'
ENV SERVER_GROUP=3
# 主数据库配置
ENV MAIN_MYSQL_HOST=''
ENV MAIN_MYSQL_PORT=''
ENV MAIN_MYSQL_ROOT_PASSWORD=88888888
ENV MAIN_MYSQL_GAME_ALLOW_IP=''
# 大区数据库配置
ENV MYSQL_HOST=''
ENV MYSQL_PORT=''
ENV MYSQL_GAME_ALLOW_IP=''
ENV AUTO_PUBLIC_IP=false
ENV PUBLIC_IP=''
ENV GM_ACCOUNT=gm_user
ENV GM_PASSWORD=gm_pass
ENV GM_CONNECT_KEY=763WXRBW3PFTC3IXPFWH
ENV GM_LANDER_VERSION=20180307
ENV DNF_DB_ROOT_PASSWORD=88888888
ENV DNF_DB_GAME_PASSWORD=uu5!^%jg
ENV WEB_USER=root
ENV WEB_PASS=123456
# 自动生成频道
ENV OPEN_CHANNEL='11,52'
# 默认关闭DDNS
ENV DDNS_ENABLE=false
ENV DDNS_DOMAIN=''
ENV DDNS_INTERVAL=10
# netbird
ENV NB_SETUP_KEY=''
ENV NB_MANAGEMENT_URL=''

# 覆盖添加目录
COPY build/dnf_data/ /
# 切换工作目录
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
