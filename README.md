# 地下城与勇士容器版本

## 说明

该项目是将地下城与勇士(毒奶粉、DNF、DOF)整合成一个Docker镜像的项目 如何想实际部署，则只需要拷贝其中的[部署文件夹](deploy)即可,即deploy目录。 本项目使用官方Centos:
6.9为基础镜像，通过增加环境变量以及初始化脚本实现 应用的快速部署。

## 自动化构建

该项目已经接入CircleCI,会自动化构建每一个版本

## 部署流程

### Centos6/7安装Docker

先升级yum源

```shell
yum update -y
```

下载docker安装脚本

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
```

运行安装docker的脚本

```shell
sudo sh get-docker.sh
```

启动docker

```shell
systemctl enable docker
systemctl restart docker
```

关闭防火墙

```shell
systemctl disable firewalld
systemctl stop firewalld
```

关闭selinux

```shell
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

创建swap

```shell
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
mkswap /var/swap.1
swapon /var/swap.1
sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
```

## 拉取镜像

以下命令二选一

```shell
docker pull registry.cn-hangzhou.aliyuncs.com/1995chen/dnf:stable  
docker tag registry.cn-hangzhou.aliyuncs.com/1995chen/dnf:stable 1995chen/dnf:stable
或直接从官方仓库拉取
docker pull 1995chen/dnf:stable
```

## 简单启动

```shell
# 创建一个目录,这里以/data为例,后续会将该目录下的mysql以及data目录挂载到容器内部
mkdir -p /data
# 初始化数据库以及基础数据文件(该过程耗时较长,可能会超过10分钟请耐心等待)
# PUBLIC_IP为公网IP地址，如果在局域网部署则用局域网IP地址，按实际需要替换
# DNF_DB_ROOT_PASSWORD为DNF数据库root密码，建议替换
# GM_ACCOUNT为登录器用户名，建议替换
# GM_PASSWORD为登录器密码，建议替换
docker run --rm -e DNF_DB_ROOT_PASSWORD=88888888 -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data 1995chen/dnf:stable /bin/bash /home/template/init/init.sh

# 启动服务
# PUBLIC_IP、DNF_DB_ROOT_PASSWORD、GM_ACCOUNT、GM_PASSWORD与上面实际运行的配置保持一致即可
docker run -d -e PUBLIC_IP=x.x.x.x -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gm_user -e GM_PASSWORD=gm_pass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 20303:20303/tcp -p 20303:20303/udp -p 20403:20403/tcp -p 20403:20403/udp -p 40403:40403/tcp -p 40403:40403/udp -p 7000:7000/tcp -p 7000:7000/udp -p 7001:7001/tcp -p 7001:7001/udp -p 7200:7200/tcp -p 7200:7200/udp -p 10011:10011/tcp -p 31100:31100/tcp -p 30303:30303/tcp -p 30303:30303/udp -p 30403:30403/tcp -p 30403:30403/udp -p 10052:10052/tcp -p 20011:20011/tcp -p 20203:20203/tcp -p 20203:20203/udp -p 30703:30703/udp -p 11011:11011/udp -p 2311-2313:2311-2313/udp -p 30503:30503/udp -p 11052:11052/udp --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g 1995chen/dnf:stable
# 该服务占有内存较大，极有可能被系统杀死,当进程被杀死时则需要重启服务
# 重启服务命令
docker restart dnf
```

## 默认的网关信息

网关端口: 881  
通讯密钥: 763WXRBW3PFTC3IXPFWH  
登录器端口: 7600  
GM账户: gm_user  
GM密码: gm_pass

## 客户端地址下载
链接: https://pan.baidu.com/s/10RgXFtpEhvRUm-hA98Am4A 提取码: fybn

## docker-compose启动

[部署文档](deploy/dnf/deploy.md)

## k8s启动

[Yaml地址](Kubernetes.md)

## 沟通交流

QQ 群:852685848  
欢迎各路大神加入,一起完善项目，成就当年梦,800万勇士冲！

## 申明

    虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
    虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
    虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
