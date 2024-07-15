# 地下城与勇士容器版本

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/5hFbZLArT4z93ByaTYNZ2x/RreRQeCp7yaWKmcyWrNDEs/tree/main.svg?style=svg&circle-token=CCIPRJ_Sg2B4EQQ3NGhtpCzrE5BgJ_cf6d6666bb4468d097db9ad01858ed43608eea82)](https://dl.circleci.com/status-badge/redirect/circleci/5hFbZLArT4z93ByaTYNZ2x/RreRQeCp7yaWKmcyWrNDEs/tree/main)
[![Docker Image](https://img.shields.io/docker/pulls/1995chen/dnf.svg?maxAge=3600)](https://hub.docker.com/r/1995chen/dnf/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/1995chen/dnf/master/LICENSE)

## Contact US
For cooperation and suggestions please contact chenl2448365088@gmail.com or yzd315695355@gmail.com

## 说明

该项目是将地下城与勇士(毒奶粉、DNF、DOF)整合成一个 Docker 镜像的项目 如果想实际部署，则只需要拷贝其中的[部署文件夹](deploy)即可，即 deploy 目录。本项目使用官方 CentOS
6.9 为基础镜像，通过增加环境变量以及初始化脚本实现 应用的快速部署。

感谢 xyz1001 大佬提供`libhook.so`优化CPU占用 [源码](https://godbolt.org/z/EKsYGh5dv)

站库分离详见 [XanderYe/dnf](https://github.com/XanderYe/dnf)

如果觉得本项目和[XanderYe/dnf](https://github.com/XanderYe/dnf)对你有帮助，可以点一下 Star 支持下我们，谢谢。

## 2.1.5 Release Plan 
```
1. 支持假人
2. 通过插件支持几款登陆器
```

## 自动化构建

该项目已经接入 CircleCI，会自动化构建每一个版本。

## 部署流程

### CentOS 6/7 安装 Docker

先升级 yum 源

```shell
yum update -y
```

下载 docker 安装脚本

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
```

运行安装 docker 的脚本

```shell
sudo sh get-docker.sh
```

启动 docker

```shell
systemctl enable docker
systemctl restart docker
```

关闭防火墙

```shell
systemctl disable firewalld
systemctl stop firewalld
```

关闭 selinux

```shell
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

### 配置虚拟内存（若内存不足 8GB）

[参考文献](https://www.cnblogs.com/EasonJim/p/7777904.html)

创建 Swap 文件

```shell
which /usr/bin/fallocate && /usr/bin/fallocate --length 8GiB /var/swap.1 || /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
mkswap /var/swap.1
swapon /var/swap.1
sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
```

查看系统是否已启用 Swap

```shell
sysctl vm.swappiness
```

如果输出最后的数字不为 0，则代表已经启用 Swap，可不做处理。

如果输出最后的数字为 0，则使用下面的命令添加 Swap 配置（设定为比起内存，优先使用 Swap）

```shell
# 其中的 100 也可以进行修改，100 代表尽可能使用虚拟内存，0 代表尽可能使用物理内存
# 物理内存远快于虚拟内存，但对于 DNF 服务来说，个位数玩家在玩时，基本体会不到差异
sed -i '$a vm.swappiness = 100' /etc/sysctl.conf
```

重新启动服务器，或执行以下命令使 Swap 配置生效：

```shell
sysctl -p
```

## 拉取镜像

[所有镜像版本可点击查看(记得点赞三连，帮助更多人了解到该镜像)](https://hub.docker.com/repository/docker/1995chen/dnf)

以下命令任选一个，可拉取镜像到本机

```shell
docker pull 1995chen/dnf:centos5-2.1.4.fix1
docker pull 1995chen/dnf:centos6-2.1.4.fix1
# 如何您需要使用 CentOS7 作为基础镜像的特殊需求,可以使用:
docker pull 1995chen/dnf:centos7-2.1.4.fix1
# 国内镜像无法拉取请使用(完整复制下面两行命令执行)
docker pull registry.cn-hangzhou.aliyuncs.com/1995chen/dnf:centos7-2.1.4.fix1 && docker tag registry.cn-hangzhou.aliyuncs.com/1995chen/dnf:centos7-2.1.4.fix1 1995chen/dnf:centos7-2.1.4.fix1
```

## 简单启动

```shell
# 创建一个目录，保存游戏的数据、PVF、日志等，这里以保存到 /data 为例
# 2.1.0 及之后的版本，在首次启动时会自动初始化 mysql 数据
mkdir -p /data/log /data/mysql /data/data

# 启动服务
# PUBLIC_IP 为公网IP地址，如果在局域网部署则用局域网IP地址，按实际需要替换
# GM_ACCOUNT 为登录器用户名，建议替换
# GM_PASSWORD 为登录器密码，建议替换
# DNF_DB_ROOT_PASSWORD 为 mysql root 密码，容器启动时会自动将 root 用户的密码修改为此值
# WEB_USER 为 supervisor web 管理页面用户名
# WEB_PASS 为 supervisor web 管理页面密码（可以访问 PUBLIC_IP:2000 来访问进程管理页面）
# --shm-size=8g【不可删除】，docker默认为64M较小，需要增加才能保证运行
# 注意，最后的 1995chen/dnf:centos5-2.1.4.fix1 部分中的 centos5，你在上一步拉取得哪个版本，则应替换为哪个版本
docker run -d -e PUBLIC_IP=x.x.x.x -e WEB_USER=root -e WEB_PASS=123456 -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gmuser -e GM_PASSWORD=gmpass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 2000:180 -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 7001:7001/tcp -p 7001:7001/udp -p 10011:10011/tcp -p 11011:11011/udp -p 10052:10052/tcp -p 11052:11052/udp -p 7200:7200/tcp -p 7200:7200/udp -p 2311-2313:2311-2313/udp --cap-add=NET_ADMIN --hostname=dnf --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g --name=dnf 1995chen/dnf:centos5-2.1.4.fix1
```

## docker-compose部署[群晖推荐]

[Yaml文件](deploy/dnf/docker-compose.yaml)

## k8s启动

[部署文档](Kubernetes.md)

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
查看Logxxxxxxxx.init文件(其中xxxxxxxx为当天时间,需要按实际情况替换),四国的初始化日志都在这里  
成功出现四国后,日志文件大概如下,四国初始化时间大概1分钟左右,请耐心等待  
[root@centos-02 siroco11]# tail -f Log20211203.init  
[09:40:23]    - RestrictBegin : 1  
[09:40:23]    - DropRate : 0  
[09:40:23]    Security Restrict End  
[09:40:23] GeoIP Allow Country Code : CN  
[09:40:23] GeoIP Allow Country Code : HK  
[09:40:23] GeoIP Allow Country Code : KR  
[09:40:23] GeoIP Allow Country Code : MO  
[09:40:23] GeoIP Allow Country Code : TW(CN)  
[09:40:32] [!] Connect To Guild Server ...  
[09:40:32] [!] Connect To Monitor Server ...  

2.查看进程  
在确保日志都正常的情况下,需要查看进程进一步确定程序正常启动  
[root@centos-02 siroco11]# ps -ef |grep df_game  
root 16500 16039 9 20:39 ? 00:01:20 ./df_game_r siroco11 start  
root 16502 16039 9 20:39 ? 00:01:22 ./df_game_r siroco52 start  
root 22514 13398 0 20:53 pts/0 00:00:00 grep --color=auto df_game  
如上结果df_game_r进程是存在的,代表成功.如果不成功可以重启服务  

3.查看进程管理页面
可以通过访问http://PUBLIC_IP:2000端口来访问进程管理页面,可以在
页面上点击dnf:game_siroco11或dnf:game_siroco52进程的Tail -f来查看日志。

## 重启服务

该服务占有内存较大，极有可能被系统杀死,当进程被杀死时则需要重启服务  
重启服务命令

```shell
docker restart dnf
```

或在进程管理页面(http://PUBLIC_IP:2000页面手动重启相关进程)。

## 默认的网关信息

```shell
网关端口: 881
通讯密钥: 763WXRBW3PFTC3IXPFWH
登录器版本: 20180307
登录器端口: 7600
GM账户: gmuser
GM密码: gmpass
```

## 可选的环境变量
当容器用最新的环境变量启动时，以下所有的环境变量，包括数据库root密码都会立即生效
需要更新配置时只需要先停止服务
```shell
docker stop dnf
docker rm dnf
```
然后用最新的环境变量设置启动服务即可
```shell
# 自动获取公网地址[默认为false]
AUTO_PUBLIC_IP
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
# DNF数据库game密码（必须8位）
DNF_DB_GAME_PASSWORD
# supervisor web页面用户名
WEB_USER
# supervisor web页面密码
WEB_PASS
# ddns开关,默认为false,打开配置为true
DDNS_ENABLE
# ddns域名
DDNS_DOMAIN
# Netbird服务器地址
NB_MANAGEMENT_URL
# Netbird初始化KEY
NB_SETUP_KEY
```
统一登陆器5.x版本，需要添加hosts，否则无法进入频道
```shell
PUBLIC_IP(你的服务器IP)  start.dnf.tw
```
请注意PUBLIC_IP手动设置后AUTO_PUBLIC_IP、DDNS、Netbird都会默认禁用。

如果需要使用AUTO_PUBLIC_IP、DDNS、Netbird需要设置PUBLIC_IP=''

最后需要注意的是PUBLIC_IP、AUTO_PUBLIC_IP、DDNS和Netbird只会有一个生效。

## 更换/新增频道
[点击查看更换频道教程](UpdateChannel.md)

## FAQ
1.点击网关登录，没反应，不出游戏（请透过Garena+执行）
* A: windows7需要用管理员权限运行网关，windows10请不要用管理员权限运行网关
* A: 无法使用虚拟机Console、VNC等访问Windows。
* A: WIN+R输入dxdiag检查显示-DirectX功能是否全部开启。
* A: 没有覆盖客户端补丁。

2.服务端不出五国
* A: 机器内存不够，swap未配置或配置后未生效，通过free -m查看swap占用内存
* A: 服务器磁盘空间是否足够
* A: 如果更换过PVF,请确保PVF是未加密的，而且需要同步更换对应的等级补丁
* A: 机器内存低于2G可以尝试修改--shm-size=2g或1g
* A: swap占用为0，通过free -m查看swap使用率，通过sysctl -p查看设置是否正确，设置正确依旧swap占用为0，需要重启服务器。

3.镜像运行报错
* A: 尝试更换其他镜像
* A: 部分阉割系统可能不支持--cpus, --memory, --memory-swap, --shm-size尝试去除这些配置

4.生成网关时出现非法字符提示
* A: 默认用户名密码gm_user,gm_pass中带有下划线"_",与统一6.x版本的网关不兼容，可以尝试使用5.x版本网关或者更换默认网关用户名和密码

5.灰频道或频道点击无法进入
* A: 检查Linux服务端防火墙是否关闭
* A: 检查云服务器厂商相关端口是否放开
* A: 客户端windows是否配置hosts
* A: PUBLIC_IP是否填错，windows需要能够访问到这个配置的PUBLIC_IP
* A: 使用统一补丁需要检查网关生成的登陆器的IP
* A: 使用Dof7.6补丁需要检查DNF.toml中的IP

6.点击登录后报错（请重新安装Init）
* A: PVF加密错误，需要重新加密PVF
* A: 使用Dof7.6补丁，需要恢复成未加密PVF

7.统一网关无法连接到数据库
* A: 数据库默认端口3000，用户名使用root，密码默认88888888 ,请确保3000端口在云服务厂商配置里放开

8.接收频道信息失败
* A: 检查Linux服务端防火墙是否关闭
* A: 检查云服务器厂商相关端口是否放开
* A: 五国未成功跑出

9.登陆器版本过期,请下载最新登陆器
* A: 生成登录器，需要和【网关设置】中登录器版本一致

10.正在连接网关，登陆器无法连接网关
* A: 检查Linux服务端防火墙是否关闭
* A: 检查云服务器厂商相关端口是否放开
* A: 五国未成功跑出

11.新建角色键盘无法输入
* A: 与客户端有关，部分客户端没优化好会出现这个问题
* A: windows7下需要用管理员权限运行启用中文输入法程序（可以加群问群友），或使用系统自带英文输入法
* A: windows10需要使用系统自带的英文输入法
* A: 使用Dof7.6补丁

12.如何挂载DP
* A: 不需要挂载DP，默认已经使用DP

13.没有固定公网IP
* A: 环境变量AUTO_PUBLIC_IP 可以启动容器时自己获取公网ip，自动重启的话需要自己写脚本去检测并重启容器
* A: 客户端使用统一网关登录器+DOF7补丁，支持域名配置；统一补丁貌似不能用域名

## 客户端地址下载
链接：https://pan.baidu.com/s/10RgXFtpEhvRUm-hA98Am4A?pwd=fybn 提取码：fybn

### 统一网关下载
链接：https://pan.baidu.com/s/1Ea80rBlPQ4tY5P18ikucfw?pwd=bbd0 提取码：bbd0

### Dof7补丁下载
链接：https://pan.baidu.com/s/1rxlGfkfHTeGwzMKUNAbSlQ?pwd=ier2 提取码：ier2

## 沟通交流

QQ 1群：852685848(已满)

QQ 2群：418505204(已满)

QQ 3群：954929189

欢迎各路大神加入。一起完善项目，成就当年梦，800万勇士冲！

(群内没有任何的收费项目)

## 学习资料

DNF 玲珑学习网：https://daf.linglonger.com

## 申明
```
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
```

## 🤝 特别感谢
特别感谢 JetBrains 为本项目赞助 License

[![Jetbrains](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg?_gl=1*ng7jek*_ga*NTA3MTc0NTg3LjE2NDEwODQzMDI.*_ga_V0XZL7QHEB*MTY0MjU1NzM4OC40LjEuMTY0MjU1ODI0Mi4w)](https://jb.gg/OpenSourceSupport)
