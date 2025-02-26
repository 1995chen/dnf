FROM centos:5.11

LABEL AUTHOR 1995chen

ENV GOROOT /usr/local/go

COPY build/Centos5/dependency/ /tmp
# 安装必要的软件
RUN cd /etc/yum.repos.d/ && rm -rf * && sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf && \
    cd /tmp && \
    # 添加源
    mv Centos5-Base.repo /etc/yum.repos.d/ && \
    mv ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt && \
    # 更新repo
    yum clean all && yum makecache && yum update -y && \
    yum install -y gcc gcc-c++ make zlib-devel libc.so.6 autoconf gettext ncurses-devel libstdc++ libstdc++.so.6 \
    glibc.i686 libssl.so.6 xulrunner.x86_64 libXtst.x86_64 initscripts iptables nc unzip bzip2 file texinfo && \ 
    ln -sf /lib/libssl.so.6 /usr/lib64/libssl.so.6 && ln -sf /usr/lib64/libcrypto.so.10 /usr/lib64/libcrypto.so.6 && \
    # 编译perl
    cd /tmp && tar -zxvf perl-5.10.0.tar.gz && cd perl-5.10.0 && ./Configure -des -Dprefix=/usr/local && \
    make && make install && rm -rf /tmp/perl-5.10.0* && \
    # 编译openssl
    cd /tmp && tar -zxvf openssl-3.3.0.tar.gz && cd openssl-3.3.0 && \
    ./Configure shared zlib-dynamic --prefix=/usr/local/ssl --openssldir=/usr/local/ssl '-Wl,-rpath,$(LIBRPATH)' && \
    make && make install && echo "/usr/local/ssl/lib64" >> /etc/ld.so.conf && \
    ldconfig -v && rm -rf /usr/bin/openssl && ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl && \ 
    ln -s /usr/local/ssl/include/openssl  /usr/include/openssl && \
    ln -s /usr/local/ssl/lib64/libssl.so /usr/local/lib/libssl.so && \
    ln -s /usr/local/ssl/lib64/libssl.so /usr/local/lib64/libssl.so && \
    ln -s /usr/local/ssl/lib64/libcrypto.so /usr/local/lib/libcrypto.so && \
    ln -s /usr/local/ssl/lib64/libcrypto.so /usr/local/lib64/libcrypto.so && \
    ln -s /etc/pki/tls/certs/ca-bundle.crt  /usr/local/ssl/cert.pem && \ 
    rm -rf /tmp/openssl-3.3.0* && \
    # 编译wget
    cd /tmp && tar -zxvf wget2-2.1.0.tar.gz && cd wget2-2.1.0 && \
    CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib64" ./configure --prefix=/usr/local/wget --with-ssl=openssl --with-libssl-prefix=/usr/local/ssl && \
    make && make install && ln -s /usr/local/wget/bin/wget2 /usr/bin/wget && rm -rf /tmp/wget2-2.1.0* && \
    # 编译gcc
    # cd /tmp && wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/gcc-5.5.0-part-1.tgz && \
    # wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/gcc-5.5.0-part-2.tgz && \
    # tar -zxvf gcc-5.5.0-part-1.tgz && tar -zxvf gcc-5.5.0-part-2.tgz && mkdir gcc-build && cd gcc-build && \
    # /tmp/gcc-5.5.0/configure --enable-languages=c,c++ --prefix=/usr/local/gcc-5.5.0 --enable-shared --enable-plugin --program-suffix=-5.5.0 --disable-multilib && \
    # make MAKEINFO="makeinfo --force" && make install && cd /tmp && rm -rf /tmp/gcc-* && \
    # echo "/usr/local/gcc-5.5.0/lib64" >> /etc/ld.so.conf && ldconfig -v && \
    # mv /usr/bin/gcc /usr/bin/gcc-4.1.2 && \
    # mv /usr/bin/g++ /usr/bin/g++-4.1.2 && \
    # mv /usr/bin/c++ /usr/bin/c++-4.1.2 && \
    # ln -s /usr/local/gcc-5.5.0/bin/gcc-5.5.0 /usr/bin/gcc-5.5.0 && \
    # ln -s /usr/local/gcc-5.5.0/bin/g++-5.5.0 /usr/bin/g++-5.5.0 && \
    # ln -s /usr/local/gcc-5.5.0/bin/c++-5.5.0 /usr/bin/c++-5.5.0 && \
    # ln -sf /usr/bin/gcc-5.5.0 /usr/bin/gcc && \
    # ln -sf /usr/bin/g++-5.5.0 /usr/bin/g++ && \
    # ln -sf /usr/bin/c++-5.5.0 /usr/bin/c++ && \
    # 编译curl
    # cd /tmp && wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/curl-8.7.1.tar.gz && \ 
    # tar -zxvf curl-8.7.1.tar.gz && cd curl-8.7.1 && \
    # CPPFLAGS="-I/usr/local/ssl/include" LDFLAGS="-L/usr/local/ssl/lib64" ./configure --prefix=/usr/local/curl --with-openssl=/usr/local/ssl --enable-static --enable-shared && \
    # make && make install && echo "/usr/local/curl/lib" >> /etc/ld.so.conf && ldconfig -v && \
    # ln -s /usr/local/curl/bin/curl /usr/bin/curl && ln /usr/local/curl/bin/curl-config /usr/bin/curl-config && \ 
    # rm -rf /tmp/curl-8.7.1* && \
    # 编译git
    # cd /tmp && wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/git-2.44.0.tar.gz && \
    # tar -zxvf git-2.44.0.tar.gz && cd git-2.44.0 && \
    # make configure && \ 
    # CPPFLAGS="-I/usr/local/curl/include" LDFLAGS="-L/usr/local/curl/lib" ./configure --prefix=/usr/local/git --without-tcltk --with-curl=/usr/local/curl && \
    # make && make install && ln -s /usr/local/git/bin/git /usr/bin/git && rm -rf /tmp/git-2.44.0* && \
    # 编译vim
    # cd /tmp && wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/vim-9.1.0380.tar.gz && \
    # tar -zxvf vim-9.1.0380.tar.gz && cd vim-9.1.0380 && \
    # CFLAGS="-gdwarf-2" ./configure --prefix=/usr/local/vim && \
    # make && make install && ln -s /usr/local/vim/bin/vim /usr/bin/vim && rm -rf /tmp/vim-9.1.0380* && \
    # 安装GO
    # cd /tmp && wget https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos5/go1.22.4.linux-amd64.tar.gz && \
    # tar -zxvf go1.22.4.linux-amd64.tar.gz && mv /tmp/go /usr/local/ && ln -s /usr/local/go/bin/go /usr/bin/go && \
    # 清理
    yum clean all && rm -rf /tmp/*
# 切换工作目录
WORKDIR /root
