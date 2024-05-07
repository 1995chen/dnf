# Base Image
FROM 1995chen/centos:6.9.1-DNF-Base

MAINTAINER 1995chen

# 定义默认环境变量
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
# 默认关闭DDNS
ENV DDNS_ENABLE=false
ENV DDNS_DOMAIN=''
ENV DDNS_INTERVAL=10
# netbird
ENV NB_SETUP_KEY=''
ENV NB_MANAGEMENT_URL=''

# 添加supervisor配置文件
ADD build/dnf_data/supervisord.conf /etc/supervisord.conf
ADD build/dnf_data/dnf.conf /etc/supervisor/conf.d/
# 将模板添加到模版目录下[后续容器启动需要先将环境变量替换,再将文件移动到正确位置]
ADD build/dnf_data/neople /home/template/neople
ADD build/dnf_data/root /home/template/root
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
# 网关配置文件
ADD build/dnf_data/Config.ini /home/template/init/
# 启动脚本
ADD build/dnf_data/docker-entrypoint.sh /
# TEA算法
ADD build/dnf_data/TeaEncrypt /
# 优化CPU
ADD build/dnf_data/libhook.so /home/template/init/
RUN chmod 777 /home/template/init/libhook.so
# 添加netbird
COPY build/dnf_data/netbird_0.27.3_linux_amd64.tar.gz /tmp/
RUN cd /tmp/ && tar -zxvf netbird_0.27.3_linux_amd64.tar.gz && mv netbird /usr/bin/ && rm -rf /tmp/*
# 添加ddns脚本
ADD build/dnf_data/ddns.sh /home/template/init/
# 放开tmp目录权限
WORKDIR /tmp
RUN chmod -R 777 /tmp
# 该目录用于存放版本文件
RUN mkdir /data
# 切换工作目录
WORKDIR /root
CMD ["/bin/bash", "/docker-entrypoint.sh"]
