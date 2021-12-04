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
如何您需要使用centos7作为基础镜像的特殊需求,可以使用:
docker pull 1995chen/dnf:centos7-latest
所有镜像版本列表请参考[记得点赞三连,帮助更多的人了解该镜像]:
https://hub.docker.com/repository/docker/1995chen/dnf
```

## 简单启动

```shell
# 创建一个目录,这里以/data为例,后续会将该目录下的mysql以及data目录挂载到容器内部
mkdir -p /data
# 初始化数据库以及基础数据文件(该过程耗时较长,可能会超过10分钟请耐心等待)
# 该初始化容器是个一次性任务,跑完会在data, mysql目录下创建初始化文件，程序运行完成后自动退出,不会留下任务容器残留
# 如果要重新初始化数据,则需要删除mysql, log, data目录重新运行该初始化命令，注意:如果目录没有清空是不会执行任何操作的
docker run --rm -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data 1995chen/dnf:stable /bin/bash /home/template/init/init.sh

# 启动服务
# PUBLIC_IP为公网IP地址，如果在局域网部署则用局域网IP地址，按实际需要替换
# GM_ACCOUNT为登录器用户名，建议替换
# GM_PASSWORD为登录器密码，建议替换
# DNF_DB_ROOT_PASSWORD为mysql root密码,容器启动是root密码会跟随该环境变量的变化自动更新
docker run -d -e PUBLIC_IP=x.x.x.x -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gm_user -e GM_PASSWORD=gm_pass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 20303:20303/tcp -p 20303:20303/udp -p 20403:20403/tcp -p 20403:20403/udp -p 40403:40403/tcp -p 40403:40403/udp -p 7000:7000/tcp -p 7000:7000/udp -p 7001:7001/tcp -p 7001:7001/udp -p 7200:7200/tcp -p 7200:7200/udp -p 10011:10011/tcp -p 31100:31100/tcp -p 30303:30303/tcp -p 30303:30303/udp -p 30403:30403/tcp -p 30403:30403/udp -p 10052:10052/tcp -p 20011:20011/tcp -p 20203:20203/tcp -p 20203:20203/udp -p 30703:30703/udp -p 11011:11011/udp -p 2311-2313:2311-2313/udp -p 30503:30503/udp -p 11052:11052/udp --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g 1995chen/dnf:stable
```

## 如何确认已经成功启动

1.查看日志 log  
├── siroco11  
│ ├── Log20211203-09.history  
│ ├── Log20211203.cri  
│ ├── Log20211203.debug  
│ ├── Log20211203.error  
│ ├── Log20211203.init  
│ ├── Log20211203.log  
│ ├── Log20211203.money  
│ └── Log20211203.snap  
└── siroco52  
├── Log20211203-09.history  
├── Log20211203.cri  
├── Log20211203.debug  
├── Log20211203.error  
├── Log20211203.init  
├── Log20211203.log  
├── Log20211203.money  
└── Log20211203.snap  
查看Logxxxx.init文件,五国的初始化日志都在这里  
成功出现五国后,日志文件大概如下,五国初始化时间大概1分钟左右,请耐心等待  
[root@centos-02 siroco11]# tail -f Log20211203.init  
[09:40:23]    - RestrictBegin : 1  
[09:40:23]    - DropRate : 0  
[09:40:23]    Security Restrict End  
[09:40:23] GeoIP Allow Country Code : CN  
[09:40:23] GeoIP Allow Country Code : HK  
[09:40:23] GeoIP Allow Country Code : KR  
[09:40:23] GeoIP Allow Country Code : MO  
[09:40:23] GeoIP Allow Country Code : TW  
[09:40:32] [!] Connect To Guild Server ...  
[09:40:32] [!] Connect To Monitor Server ...  
2.查看进程  
在确保日志都正常的情况下,需要查看进程进一步确定程序正常启动  
[root@centos-02 siroco11]# ps -ef |grep df_game  
root 16500 16039 9 20:39 ? 00:01:20 ./df_game_r siroco11 start  
root 16502 16039 9 20:39 ? 00:01:22 ./df_game_r siroco52 start  
root 22514 13398 0 20:53 pts/0 00:00:00 grep --color=auto df_game  
如上结果df_game_r进程是存在的,代表成功.如果不成功可以重启服务

## 重启服务

该服务占有内存较大，极有可能被系统杀死,当进程被杀死时则需要重启服务  
重启服务命令

```shell
docker restart dnf
```

## 默认的网关信息

网关端口: 881  
通讯密钥: 763WXRBW3PFTC3IXPFWH   
登录器版本: 20180307  
登录器端口: 7600  
GM账户: gm_user  
GM密码: gm_pass  

## 可选的环境变量
当容器用最新的环境变量启动时，以下所有的环境变量，包括数据库root密码都会立即生效
需要更新配置时只需要先停止服务
```shell
docker stop dnf
docker rm dnf
```
然后用最新的环境变量设置启动服务即可
```shell
# 公网或局域网IP地址
PUBLIC_IP
# GM管理员账号
GM_ACCOUNT
# GM管理员密码
GM_PASSWORD
# GM连接KEY(自定以密钥请使用网关生成的密钥，因为密钥有格式限制，不符合格式的密钥会导致登录器一致卡在网关连接那里)
GM_CONNECT_KEY
# GM登录器版本
GM_LANDER_VERSION
# DNF数据库root密码
DNF_DB_ROOT_PASSWORD
```

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
