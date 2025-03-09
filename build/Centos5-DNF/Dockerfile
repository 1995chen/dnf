FROM 1995chen/centos:5.11.7

LABEL AUTHOR 1995chen

# 安装环境
RUN cd /tmp && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/meld3-2.0.1.tar.gz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/Python-2.7.13.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/setuptools-18.0.1.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/pip-7.1.0.tar.gz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/supervisor-3.1.3.tar.gz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/GeoIP-1.4.8.tgz && \
    wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/common_pkgs/lib.tgz && \
    # 解压
    tar -zxvf meld3-2.0.1.tar.gz && \
    tar -zxvf supervisor-3.1.3.tar.gz && \
    tar -zxvf Python-2.7.13.tgz && \
    tar -zxvf setuptools-18.0.1.tgz && \
    tar -zxvf pip-7.1.0.tar.gz && \
    tar -zxvf GeoIP-1.4.8.tgz || true && \
    tar -zxvf lib.tgz && \
    # 移动so文件
    mv /tmp/*.so /lib/ && mv /tmp/*.so.1 /lib/ && \
    # 编译python2.7 supervisor
    cd /tmp/Python-2.7.13 && ./configure && make install && \
    cd /tmp/setuptools-18.0.1 && python2.7 setup.py install && \
    cd /tmp/pip-7.1.0 && python2.7 setup.py install && \
    cd /tmp/meld3-2.0.1 && python2.7 setup.py install && \
    cd /tmp/supervisor-3.1.3 && python2.7 setup.py install && \
    # 安装mysql
    rpm -ivh /tmp/MySQL-shared-compat-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-devel-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-client-community-5.0.95-1.rhel5.x86_64.rpm && \
    rpm -ivh /tmp/MySQL-server-community-5.0.95-1.rhel5.x86_64.rpm && \
    service mysql stop && rm -rf /var/lib/mysql/* && \
    # 编译GeoIP
    mv /tmp/GeoIP-1.4.8 /home/ && cd //home/GeoIP-1.4.8/ && chmod 777 configure && ./configure && make && make install && \
    # 本地端口转发工具
    yum install socat -y && \
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
