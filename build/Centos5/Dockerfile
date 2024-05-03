# Base Image
FROM centos:5.11

MAINTAINER 1995chen

# 删除旧源
RUN cd /etc/yum.repos.d/ && \
    rm -rf *.repo && \
    sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf
# 添加源
ADD build/Centos5/*.repo /etc/yum.repos.d/
# 更新ca证书
ADD build/Centos5/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt
# 添加perl
COPY build/Centos5/perl-5.10.0.tar.gz /tmp/
# 添加openssl
COPY build/Centos5/openssl-3.3.0.tar.gz /tmp/
# 添加curl
COPY build/Centos5/curl-8.7.1.tar.gz /tmp/
# 添加wget
COPY build/Centos5/wget2-2.1.0.tar.gz /tmp/
# 添加git
COPY build/Centos5/git-2.44.0.tar.gz /tmp/
# 添加vim
COPY build/Centos5/vim-9.1.0380.tar.gz /tmp/
# 更新repo
RUN yum clean all && yum makecache && yum update -y && \
    yum install -y gcc gcc-c++ make zlib-devel libc.so.6 autoconf gettext ncurses-devel libstdc++ libstdc++.so.6 \
    glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts iptables && \ 
    yum clean all && ln -sf /lib/libssl.so.6 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6
WORKDIR /tmp
# 编译perl
RUN tar -zxvf perl-5.10.0.tar.gz && cd perl-5.10.0 && ./Configure -des -Dprefix=/usr/local && \
    make && make install && rm -rf /tmp/perl-5.10.0*
# 编译openssl
RUN tar -zxvf openssl-3.3.0.tar.gz && cd openssl-3.3.0 && \
    ./Configure shared zlib-dynamic --prefix=/usr/local/ssl --openssldir=/usr/local/ssl '-Wl,-rpath,$(LIBRPATH)' && \
    make && make install && echo "/usr/local/ssl/lib64" >> /etc/ld.so.conf && \
    ldconfig -v && rm -rf /usr/bin/openssl && ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl && \ 
    ln -s /usr/local/ssl/include/openssl  /usr/include/openssl && \
    ln -s /usr/local/ssl/lib64/libssl.so /usr/local/lib/libssl.so && \
    ln -s /usr/local/ssl/lib64/libssl.so /usr/local/lib64/libssl.so && \
    ln -s /usr/local/ssl/lib64/libcrypto.so /usr/local/lib/libcrypto.so && \
    ln -s /usr/local/ssl/lib64/libcrypto.so /usr/local/lib64/libcrypto.so && \
    ln -s /etc/pki/tls/certs/ca-bundle.crt  /usr/local/ssl/cert.pem && \ 
    rm -rf /tmp/openssl-3.3.0*
# 编译wget
RUN tar -zxvf wget2-2.1.0.tar.gz && cd wget2-2.1.0 && \
    CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib64" ./configure --prefix=/usr/local/wget --with-ssl=openssl --with-libssl-prefix=/usr/local/ssl && \
    make && make install && ln -s /usr/local/wget/bin/wget2 /usr/bin/wget && rm -rf /tmp/wget2-2.1.0*
# 编译curl
RUN tar -zxvf curl-8.7.1.tar.gz && cd curl-8.7.1 && \
    CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib64" ./configure --prefix=/usr/local/curl --with-openssl=/usr/local/ssl --enable-static --enable-shared && \
    make && make install && echo "/usr/local/curl/lib" >> /etc/ld.so.conf && ldconfig -v && \
    ln -s /usr/local/curl/bin/curl /usr/bin/curl && ln /usr/local/curl/bin/curl-config /usr/bin/curl-config && \ 
    rm -rf /tmp/curl-8.7.1*
# 编译git
RUN tar -zxvf git-2.44.0.tar.gz && cd git-2.44.0 && \
    make configure && \ 
    CPPFLAGS="-I/usr/local/curl/include" LDFLAGS="-L/usr/local/curl/lib" ./configure --prefix=/usr/local/git --without-tcltk --with-curl=/usr/local/curl && \
    make && make install && ln -s /usr/local/git/bin/git /usr/bin/git && rm -rf /tmp/git-2.44.0*
# 编译vim
RUN tar -zxvf vim-9.1.0380.tar.gz && cd vim-9.1.0380 && \
    ./configure --prefix=/usr/local/vim && \
    make && make install && ln -s /usr/local/vim/bin/vim /usr/bin/vim && rm -rf /tmp/vim-9.1.0380*
# 切换工作目录
WORKDIR /root
