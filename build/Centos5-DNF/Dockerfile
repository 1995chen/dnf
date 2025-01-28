# Base Image
FROM 1995chen/centos:5.11.3-DNF-Base

MAINTAINER 1995chen

# 定义默认环境变量
# 是否连接远程bridge
ENV MAIN_BRIDGE_IP='127.0.0.1'
ENV SERVER_GROUP_DB=''
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

# 添加mysql配置
COPY build/dnf_data/my.cnf /etc/
# 添加频道脚本
ADD build/dnf_data/channel /home/template/init/channel
# 添加monitor_ip脚本
ADD build/dnf_data/monitor_ip /home/template/init/monitor_ip
# 添加mysql_proxy
ADD build/dnf_data/mysql_proxy /home/template/init/mysql_proxy
# 添加daily_job
ADD build/dnf_data/daily_job /home/template/init/daily_job
# 添加netbird
ADD build/dnf_data/netbird /home/template/init/netbird
# 添加supervisor配置文件
ADD build/dnf_data/supervisor /home/template/init/supervisor
# 添加证书
ADD build/dnf_data/privatekey.pem /home/template/init/
ADD build/dnf_data/publickey.pem /home/template/init/
# 初始化sql脚本
COPY build/dnf_data/init_sql.tgz /home/template/init/
# 初始化版本文件
COPY build/dnf_data/Script.tgz /home/template/init/
# 初始化等级补丁
ADD build/dnf_data/df_game_r /home/template/init/
# 初始化脚本
ADD build/dnf_data/init.sh /home/template/init/
ADD build/dnf_data/init_local_db.sh /home/template/init/
ADD build/dnf_data/init_main_db.sh /home/template/init/
ADD build/dnf_data/init_server_group_db.sh /home/template/init/
# 网关配置文件
ADD build/dnf_data/Config.ini /home/template/init/
# 添加默认DP文件
ADD build/dnf_data/libhook.so /home/template/init/
# 链接supervisor配置文件
RUN rm -rf /etc/supervisord.conf && mkdir -p /etc/supervisor/conf.d
RUN ln -s /home/template/init/supervisor/supervisord.conf /etc/supervisord.conf
RUN ln -s /home/template/init/netbird/netbird.conf /etc/supervisor/conf.d/netbird.conf
# 将模板添加到模版目录下[后续容器启动需要先将环境变量替换,再将文件移动到正确位置]
ADD build/dnf_data/neople /home/template/neople
ADD build/dnf_data/root /home/template/root
# 启动脚本
ADD build/dnf_data/docker-entrypoint.sh /
# TEA算法
ADD build/dnf_data/TeaEncrypt /
# 优化CPU
RUN chmod 777 /home/template/init/libhook.so
# 添加netbird可执行文件
COPY build/dnf_data/netbird_0.27.3_linux_amd64.tar.gz /tmp/
RUN cd /tmp/ && tar -zxvf netbird_0.27.3_linux_amd64.tar.gz && mv netbird /usr/bin/ && rm -rf /tmp/*
# 放开tmp目录权限
WORKDIR /tmp
RUN chmod -R 777 /tmp
# 该目录用于存放版本文件
RUN mkdir /data
# 切换工作目录
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
