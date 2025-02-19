# 地下城与勇士容器版本

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/5hFbZLArT4z93ByaTYNZ2x/RreRQeCp7yaWKmcyWrNDEs/tree/main.svg?style=svg&circle-token=CCIPRJ_Sg2B4EQQ3NGhtpCzrE5BgJ_cf6d6666bb4468d097db9ad01858ed43608eea82)](https://dl.circleci.com/status-badge/redirect/circleci/5hFbZLArT4z93ByaTYNZ2x/RreRQeCp7yaWKmcyWrNDEs/tree/main)
[![Docker Image](https://img.shields.io/docker/pulls/1995chen/dnf.svg?maxAge=3600)](https://hub.docker.com/r/1995chen/dnf/)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/1995chen/dnf/master/LICENSE)

## 概述

该项目是将地下城与勇士(毒奶粉、DNF、DOF)整合成一个 Docker 镜像的项目，本项目使用官方 `CentOS-5/6/7`为基础镜像，通过增加环境变量以及初始化脚本实现 应用的快速部署。

如果觉得本项目和[XanderYe/dnf](https://github.com/XanderYe/dnf)对你有帮助，可以点一下 Star 支持下我们，谢谢。

## 3.0.0 Release Plan 
```
1. 支持假人
2. 通过插件支持几款登陆器
```

## 2025年计划

[支持新的DP插件](https://tieba.baidu.com/p/9366042070?&share=9105&fr=sharewise&is_video=false&unique=B2A11FA6311C7A25903F0C33D1E2FEC1&st=1739609146&client_type=1&client_version=12.75.1.0&sfc=qqfriend&share_from=post)

## 2.1.7 版本升级注意事项(首次部署请忽略)

<font color="red">
特别注意：由于2.1.7版本引入多大区功能，我们对原有希洛克大区端口进行过调整。

对于从旧版本升级的镜像，需要调整相应的频道端口号，并配置大区数据库。
具体来说，需要新增环境变量: SERVER_GROUP_DB=cain

</font>

| 2.1.7版本前频道端口 | 变更后频道端口 |
| ------- | ------- |
| 10011 | 30011 |
| 11011 | 31011 |
| 10052 | 30052 |
| 11052 | 31052 |
| 7200 | 7300 |

此外，本次升级镜像需要删除data文件夹下的所有文件夹（PVF、登记补丁、密钥等文件除外）。

## 环境配置
我们可以根据以下指南，在Linux服务器上进行初始化，并安装所需软件。理论上，这个镜像可以在任何未修改过的Linux操作系统上运行（不包括ARM架构）。

[初始化Linux服务器](doc/PrepareLinux.md)

## 快速开始

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
# 注意，最后的 1995chen/dnf:centos5-2.1.5 部分中的 centos5，你在上一步拉取得哪个版本，则应替换为哪个版本
docker run -d -e PUBLIC_IP=x.x.x.x -e WEB_USER=root -e WEB_PASS=123456 -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gmuser -e GM_PASSWORD=gmpass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 2000:180 -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 7001:7001/tcp -p 7001:7001/udp -p 30011:30011/tcp -p 31011:31011/udp -p 30052:30052/tcp -p 31052:31052/udp -p 7200:7200/tcp -p 7200:7200/udp -p 2311-2313:2311-2313/udp --cap-add=NET_ADMIN --hostname=dnf --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g --name=dnf 1995chen/dnf:centos5-2.1.7.fix2
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
查看Logxxxxxxxx.init文件(其中xxxxxxxx为`当天时间`,需要按实际情况替换),四国的初始化日志都在这里  
成功出现四国后,日志文件大概如下,四国初始化时间大概1分钟左右,请耐心等待  
[root@centos-02 siroco11]# tail -f Log$(date +%Y%m%d).init  
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

## 默认的网关信息

```shell
网关端口: 881
通讯密钥: 763WXRBW3PFTC3IXPFWH
登录器版本: 20180307
登录器端口: 7600
GM账户: gmuser
GM密码: gmpass
```

## 重启服务

该服务占有内存较大，极有可能被系统杀死,当进程被杀死时则需要重启服务  
重启服务命令

```shell
docker restart dnf
```

或在进程管理页面(http://PUBLIC_IP:2000页面手动重启相关进程)。

## 常见问题

1.点击网关登录，没反应，不出游戏（请透过Garena+执行）
* A: windows7需要用管理员权限运行网关，windows10请不要用管理员权限运行网关
* A: 无法使用虚拟机Console、VNC等访问Windows。
* A: WIN+R输入dxdiag检查显示-DirectX功能是否全部开启。
* A: 没有覆盖客户端补丁。
* A: 统一登陆器5.x版本，需要添加`hosts`[start.dnf.tw]，否则无法进入频道

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
* A: 公钥私钥文件是否匹配

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

14.无法连接数据库
* A: 外网访问数据库端口默认为3000端口，不是3306
* A: game用户默认无法外网访问，请使用root账号和root密码连接数据库

## 高级部署

[点击查看更多部署方式](doc/OtherDeploy.md)

## 如何构建自定义镜像

该项目已经接入 CircleCI，您在本项目的任意分支提交代码均会触发镜像构建。镜像的版本为本次提交commit-id的前7位。

## 客户端地址下载
链接：https://pan.baidu.com/s/10RgXFtpEhvRUm-hA98Am4A?pwd=fybn 提取码：fybn

### 统一网关下载
链接：https://pan.baidu.com/s/1Ea80rBlPQ4tY5P18ikucfw?pwd=bbd0 提取码：bbd0

### Dof7补丁下载
链接：https://pan.baidu.com/s/1rxlGfkfHTeGwzMKUNAbSlQ?pwd=ier2 提取码：ier2

## DNF台服架构图
[点击查看DNF台服架构图](doc/ArchitectureDiagram.md)

## 沟通交流

QQ 1群：852685848(已满)

QQ 2群：418505204(已满)

QQ 3群：954929189

欢迎各路大神加入。一起完善项目，成就当年梦，800万勇士冲！

(群内没有任何的收费项目)

## 社区

DNF 玲珑学习网：https://daf.linglonger.com

XanderYe站库分离镜像：[XanderYe/dnf](https://github.com/XanderYe/dnf)

`libhook.so`优化CPU占用源码：https://godbolt.org/z/EKsYGh5dv

## 申明
```
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
```

## 🤝 特别感谢

作为一位开源库的作者，我要衷心感谢所有支持和贡献给我项目的人。您的热情参与和无私奉献让这个项目变得更加强大和有意义。没有您的支持，这个项目将无法取得如此巨大的成功。

感谢您无私分享您的时间、知识和技能，让我们能够共同推动开源社区的发展。您的贡献不仅仅是对我个人的支持，更是对整个开源精神的认可和传承。

在未来的道路上，我将继续努力改进和完善这个项目，以回报您的支持与信任。希望我们能够继续保持联系，共同见证这个项目的成长与发展。

再次感谢您的支持与帮助！
