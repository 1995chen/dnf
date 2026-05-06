# 地下城与勇士容器版本

[![CI](https://github.com/llnut/dnf/actions/workflows/docker.yml/badge.svg)](https://github.com/llnut/dnf/actions/workflows/docker.yml)
[![Docker Hub](https://img.shields.io/badge/docker-available-blue)](https://hub.docker.com/r/llnut/dnf/)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-available-blue)](https://github.com/llnut/dnf/pkgs/container/dnf)
[![quay.io](https://img.shields.io/badge/quay.io-available-blue)](https://quay.io/repository/llnut/dnf)
[![ACR](https://img.shields.io/badge/ACR-available-blue)](https://crpi-0ghho6wxim378ik8.cn-hangzhou.personal.cr.aliyuncs.com/llnut/dnf)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/llnut/dnf/qf-1031/LICENSE)

## 概述

本项目基于 [1995chen/dnf](https://github.com/1995chen/dnf) 适配 **清风-1031** 版本，将地下城与勇士（毒奶粉、DNF、DOF）打包为 Docker 镜像，支持单镜像部署和[端库分离](#高级部署)部署，支持 `Debian 13`、`Almalinux 9`、`Ubuntu 26`、`CentOS 7` 四种基础镜像，通过环境变量和初始化脚本实现快速部署。

## 部署前须知

- 本项目使用 [llnut 登录器](https://github.com/llnut/dnf-login)，环境变量和端口与 1995chen 版本不同，请使用本仓库的配置文件部署。详细区别见[与 1995chen/dnf 的环境变量和端口区别](#vs-1995chen-dep)。
- 若您需要从旧版本升级，请先阅读[从旧版本升级](#upgrade)。
- Docker 29 及以上版本需要先[配置 Docker seccomp 兼容规则](doc/PrepareLinux.md#seccomp-profile)，并按照[常见问题中的说明](#qa-seccomp-profile)调整启动配置，否则服务端会启动失败。
- 中国大陆用户若镜像拉取失败，可使用[阿里云 ACR 镜像](doc/PrepareLinux.md#acr-image)。
- 统一网关用户请拉取 `tongyigate` 后缀的镜像，该镜像后续不再维护。

---

<a id="quick-start"></a>
## 快速开始

### 第一步：准备 Linux 环境

参考以下指南完成服务器初始化。镜像支持 x86_64 架构的 Linux 系统。

[初始化 Linux 服务器](doc/PrepareLinux.md)

### 第二步：启动服务端

```shell
# 创建目录，保存游戏数据、PVF、日志等，这里以 /data 为例
mkdir -p /data/log /data/mysql /data/data

# 启动服务
# PUBLIC_IP        公网 IP 地址，局域网部署则填局域网 IP
# DNF_DB_ROOT_PASSWORD  mysql root 密码，容器启动时会自动将 root 密码修改为此值
# WEB_USER/WEB_PASS    supervisor 进程管理页面账号密码（访问 PUBLIC_IP:2000）
# GATE_AES_KEY     dnf-gate-server AES 通讯密钥，需与登录器配置一致，可通过 openssl rand -hex 32 生成
# CLIENT_POOL_SIZE 启动时分配的客户端池大小，单人可设为 3，多人按需增加，最大 1000
# --shm-size=8g    【不可删除】docker 默认 64M 太小，必须增大才能保证运行
# 注意：镜像名中的 debian13 应与上一步拉取的版本一致
docker run -d \
  -e PUBLIC_IP=x.x.x.x \
  -e WEB_USER=root \
  -e WEB_PASS=123456 \
  -e DNF_DB_ROOT_PASSWORD=88888888 \
  -e GATE_AES_KEY=a1b2c3d4e5f6789012345678901234567890abcdef0123456789abcdef012345 \
  -e CLIENT_POOL_SIZE=10 \
  -v /data/log:/home/neople/game/log \
  -v /data/mysql:/var/lib/mysql \
  -v /data/data:/data \
  -p 2000:180 \
  -p 3000:3306/tcp \
  -p 5505:5505/tcp \
  -p 7001:7001/tcp \
  -p 7001:7001/udp \
  -p 30011:30011/tcp \
  -p 31011:31011/udp \
  -p 30052:30052/tcp \
  -p 31052:31052/udp \
  -p 7300:7300/tcp \
  -p 7300:7300/udp \
  -p 2311-2313:2311-2313/udp \
  --cap-add=NET_ADMIN \
  --hostname=dnf \
  --cpus=1 \
  --memory=1g \
  --memory-swap=-1 \
  --shm-size=8g \
  --name=dnf \
  llnut/dnf:debian13-qf1031-latest
```

### 第三步：确认服务端启动成功

**1. 查看日志**

查看 `/data/log` 目录下的 `.init` 日志文件：

~~~shell
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
  ├── ...
~~~

初始化约 1 分钟，成功后 `.init` 日志中会出现以下内容：

~~~shell
[root@centos-02 siroco11] tail -f Log$(date +%Y%m%d).init
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
~~~

**2. 查看进程**

~~~shell
[root@centos-02 siroco11] ps -ef | grep df_game
root 16500 16039 9 20:39 ? 00:01:20 ./df_game_r siroco11 start
root 16502 16039 9 20:39 ? 00:01:22 ./df_game_r siroco52 start
~~~

`df_game_r` 进程存在即代表成功。

**3. 查看进程管理页面**

访问 `http://PUBLIC_IP:2000`，点击 `dnf:game_siroco11` 或 `dnf:game_siroco52` 进程的 `Tail -f` 查看实时日志。

### 第四步：配置客户端

下载客户端：[百度网盘](https://pan.baidu.com/s/1AuDJ-VO4A9uToAsrg6ETGw?pwd=sora)，提取码：`sora`，下载后解压。

**1. 设置登录器**

- 打开游戏根目录中的 `dnf-launcher.exe`
- 点击下方的 ***设置*** 按钮，进入设置界面：
    - **服务器地址**：`http://${PUBLIC_IP}:5505`（启用 HTTPS 则为 `https://${PUBLIC_IP}:5504`），PUBLIC_IP 与第二步中 `PUBLIC_IP` 的值保持一致
    - **AES 密钥**：与第二步中 `GATE_AES_KEY` 的值保持一致
- 滚动到底部，点击保存

**2. 开始游戏**

返回登录器首页，创建账号并登录游戏。

---

## 重启服务

服务占用内存较大，可能被 OOM 杀死。重启命令：

```shell
docker restart dnf
```

或在进程管理页面（`http://PUBLIC_IP:2000`）手动重启相关进程。

---

<a id="upgrade"></a>
## 从旧版本升级

### 升级到替换了 llnut 登录器 0.2.1 的版本（镜像发布时间 2026.3.8）

拉取并重启最新镜像后，需重新下载本仓库提供的 20260308 版本客户端并完成[登录器设置](#第四步配置客户端)。

### 升级到 llnut 登录器 0.3.0 的版本（镜像发布时间 2026.3.26）

拉取并重启最新镜像后，可通过以下任一方式更新客户端：

- 重新下载本仓库提供的 20260326 版本客户端
- 下载 `20260308-to-20260326-升级补丁.7z`，解压并覆盖到 20260308 版本的客户端目录中

新版客户端不再需要手动配置 `mlpz.ini`，游戏服务器 IP 由登录器自动从服务端获取。

### 从 CentOS 7 切换到 Debian 13 / Alma 9 / Ubuntu 26 镜像

Debian 13、Alma 9、Ubuntu 26 三种镜像之间可以直接切换，无需清理数据。**但 CentOS 7 与这三种镜像互不兼容**，切换前必须清除所有挂载目录数据：

```bash
docker stop dnf && docker rm dnf
rm -rf /data/log/* /data/mysql/* /data/data/* # 路径按实际情况填写
```

**清除后数据不可恢复，请提前备份。** 若不想清理数据，也可用数据库备份工具将旧库数据导入到新库。

---

## 高级部署

项目支持以下部署模式：

- 一体部署：单容器包含游戏服务端和数据库，参考[快速开始](#quick-start)。
- 端库分离：游戏服务端与数据库 分别部署在独立容器中，便于数据库独立管理、备份和资源隔离。
- 多频道 / 多大区：单容器开多个频道，或在单台/多台服务器上同时运行多个大区。
- Kubernetes：基于 K8s 部署服务端。

[点击查看详细文档](doc/OtherDeploy.md)

---

## 常见问题

1.点击网关登录，没反应，不出游戏（请透过Garena+执行）
* A: 无法使用虚拟机Console、VNC等访问Windows。
* A: WIN+R输入dxdiag检查显示-DirectX功能是否全部开启。

2.服务端不出五国
* A: 机器内存不够，swap未配置或配置后未生效，通过free -m查看swap占用内存
* A: 服务器磁盘空间是否足够
* A: 如果更换过PVF,请确保PVF是未加密的，而且需要同步更换对应的等级补丁
* A: 机器内存低于2G可以尝试修改--shm-size=2g或1g
* A: swap占用为0，通过free -m查看swap使用率，通过sysctl -p查看设置是否正确，设置正确依旧swap占用为0，需要重启服务器。

3.镜像运行报错
* A: 尝试更换其他镜像
* A: 部分阉割系统可能不支持--cpus, --memory, --memory-swap, --shm-size尝试去除这些配置

4.设置登录器AES密钥时报错："配置无效: AES key must be exactly 64 hex characters"
* A: AES密钥长度错误，请仔细检查密钥内容

5.设置登录器AES密钥时报错："配置无效: AES key must contain only hex characters (0-9, a-f, A-F)"
* A: AES密钥格式错误，请仔细检查密钥内容

6.点击登录后报错: "网络错误: error sending request for url ...."
* A: 设置界面服务器地址设置错误
* A: 服务端网关启动失败，请检查`/data/data/log/llnut_gate.log`中是否有报错信息
* A: 防火墙未开放网关端口(http端口默认为5505，https端口默认为5504)

7.灰频道或频道点击无法进入
* A: 检查Linux服务端防火墙是否关闭
* A: 检查云服务器厂商相关端口是否放开
* A: 客户端windows是否配置hosts
* A: PUBLIC_IP是否填错，windows需要能够访问到这个配置的PUBLIC_IP
* A: 若使用Dof7.6补丁需要检查DNF.toml中的IP是否为服务端PUBLIC_IP
* A: 公钥私钥文件是否匹配

8.点击登录后报错（请重新安装Init）
* A: PVF加密错误，需要重新加密PVF
* A: 若使用Dof7.6补丁，需要恢复成未加密PVF

9.接收频道信息失败
* A: 检查Linux服务端防火墙是否关闭
* A: 检查云服务器厂商相关端口是否放开
* A: 五国未成功跑出
* A: 若使用原版清风2026.2.1的客户端，请更换本项目提供的清风客户端

10.如何启用dnf-gate-server的https支持
* A: 将ssl证书和私钥放置在`/data`目录中，之后设置容器的`GATE_TLS_CERT_PATH`和`GATE_TLS_KEY_PATH`环境变量为正确的证书和私钥路径，重启容器即可

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

15.服务器一直卡在`Init DataManager`日志循环
* A: 内存或者swap不足，可以将swap设置为10g或更大(对应docker run参数`--shm-size=10g`同时调整)
* A: swap占用为0，通过free -m查看swap使用率，通过sysctl -p查看设置是否正确，设置正确依旧swap占用为0，需要重启服务器。参考 [这里](./doc/PrepareLinux.md#%E9%85%8D%E7%BD%AE%E4%BA%A4%E6%8D%A2%E7%A9%BA%E9%97%B4%E8%8B%A5%E5%86%85%E5%AD%98%E4%B8%8D%E8%B6%B3-8gb) 进行设置

16.配置了CLIENT_POOL_SIZE之后发现`df_bridge_r`和`df_channel_r`内存占用依然都为1.3GB
* A: 若您是从旧版本升级而来，请先删除docker挂载目录中的`/data/run/start_bridge.sh`和`/data/run/start_channel.sh`，之后重启服务端即可生效(只需删除一次即可，后续启动服务端无需再次删除)。

17.游戏内包括角色职业，游戏公告等很多处地方显示乱码
* A: 若您使用Dof补丁大合集，请编辑其配置文件，将简体PVF设置为1

18.游戏内按 Z 键无法释放技能
* A: 游戏默认关闭了 Z 键位，请打开游戏键位设置重新设置 Z 技能。

19.更换其他登录器后无法连接频道
* A: 为了提升安全性，本项目没有内置任何公开的游戏公私钥，而是在初次部署时生成全新的公私钥。若需要使用其他内置了私钥的登录器，可以手动获取其公钥或通过[此网盘链接](https://pan.baidu.com/s/1ahR84V3otuy5WYAZD6kvkQ?pwd=sora)下载旧版本公私钥并替换到`/data`目录中，网盘提取码为`sora`。注意，使用公开的公私钥时，一旦泄露了服务端的PUBLIC_IP，攻击者即可在不知道游戏账号密码的前提下随意游玩您服务端任意账号下的任意游戏角色，请务必谨慎。

20.使用3.26及之后的客户端版本，使用补丁大合集无法启动游戏
* A: 按照补丁大合集文档中标注的正确安装方式进行安装，即：拷贝 DNF.exe 与 DNF.toml 到游戏目录，删除游戏目录中除了补丁大合集本体、文件夹、audio.xml、Script.pvf、登录器以外的所有文件。

<a id="qa-seccomp-profile"></a>
21.升级 Docker (或安装最新 Docker) 后很多服务频繁重启，日志显示 `Could not create a UDP socket : 38`
* A: Docker 29 版本默认 seccomp 策略变更导致服务端创建 UDP socket 失败。可使用 `seccomp=unconfined` 快速解决(安全隐患大，不建议使用)。推荐使用 v0.2.1 版本的seccomp profile 启动容器，在宿主机下载兼容版 profile：
```bash
sudo curl -fsSL https://raw.githubusercontent.com/moby/profiles/refs/tags/seccomp/v0.2.1/seccomp/default.json \
  -o /etc/docker/seccomp-profile-v0.2.1.json
```
如果使用 docker compose，在 dnf 服务中加入以下配置，然后重新启动容器：
```yaml
security_opt:
  - seccomp=/etc/docker/seccomp-profile-v0.2.1.json
```
如果使用 docker run，启动参数中加入 `--security-opt seccomp=/etc/docker/seccomp-profile-v0.2.1.json` 后启动容器即可。

---

<a id="vs-1995chen-dep"></a>
## 与 1995chen/dnf 的环境变量和端口区别

### 新增环境变量（llnut/dnf 特有）

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `GATE_AES_KEY` | a1b2c3d4e5f678901234567890123456<br>7890abcdef0123456789abcdef012345 | dnf-gate-server AES 通讯密钥，需与登录器配置一致 |
| `GATE_BIND_ADDRESS` | `0.0.0.0:5505` | dnf-gate-server HTTP 监听地址 |
| `RSA_PRIVATE_KEY_PATH` | `/data/privatekey.pem` | RSA 私钥路径 |
| `INITIAL_CERA` | `1000` | 新账号初始点券 |
| `INITIAL_CERA_POINT` | `0` | 新账号初始代币券 |
| `GATE_RUST_LOG` | `info,dnf_gate_server=debug` | dnf-gate-server 日志级别 |
| `GATE_TLS_CERT_PATH` | 无 | TLS 证书路径，与 `GATE_TLS_KEY_PATH` 同时设置时启用 HTTPS |
| `GATE_TLS_KEY_PATH` | 无 | TLS 私钥路径 |
| `GATE_TLS_BIND_ADDRESS` | `0.0.0.0:5504` | dnf-gate-server HTTPS 监听地址 |
| `GATE_TLS_ONLY` | `false` | 启用后仅允许 HTTPS 连接，拒绝 HTTP 请求 |
| `GAME_SERVER_IP` | `PUBLIC_IP` | 游戏服务器 IP，当网关与游戏服务端不在同一台机器时需单独配置 |

### 移除环境变量（1995chen/dnf 特有）

| 环境变量 | 原默认值 | 说明 |
|---|---|---|
| `GM_ACCOUNT` | `gmuser` | GM 账号 |
| `GM_PASSWORD` | `gmpass` | GM 密码 |
| `GM_CONNECT_KEY` | `763WXRBW3PFTC3IXPFWH` | GM 通讯密钥 |
| `GM_LANDER_VERSION` | `20180307` | 登录器版本 |

### 端口变化

| 用途 | llnut/dnf | 1995chen/dnf |
|---|---|---|
| 登录服务 HTTP | `5505` | `7600`（统一登陆器）、`881`（统一网关） |
| 登录服务 HTTPS | `5504`（可选，启用 TLS 后开放） | — |

---

## DNF 台服架构图

[点击查看 DNF 台服架构图](doc/ArchitectureDiagram.md)

---

## 沟通交流

QQ 1群：852685848(已满)

QQ 2群：418505204(已满)

QQ 3群：954929189(已满)

QQ 5群：738105518(已满)

QQ 6群：933010289

QQ 7群：971177373

欢迎各路大神加入。一起完善项目，成就当年梦，800万勇士冲！

(群内没有任何的收费项目)

## 社区

`libhook.so`优化CPU占用源码：[https://godbolt.org/z/EKsYGh5dv](https://godbolt.org/z/EKsYGh5dv)  
`DofSlim`优化服务端内存占用源码：[https://github.com/llnut/DofSlim](https://github.com/llnut/DofSlim)  
`Sorahk`多功能高性能连发程序: [https://github.com/llnut/Sorahk](https://github.com/llnut/Sorahk)  
`dnf-login`llnut登录器: [https://github.com/llnut/dnf-login](https://github.com/llnut/dnf-login)  
`dnf-compat-layer`新版linux镜像兼容层: [https://github.com/llnut/dnf-compat-layer](https://github.com/llnut/dnf-compat-layer)

## 申明
```
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
```

## 🤝 特别感谢

特别感谢清风和原作者 1995chen 以及 QQ 交流群各位热心人士对本项目的支持。以下是 1995chen 的话，也是我想说的话：

作为一位开源库的作者，我要衷心感谢所有支持和贡献给我项目的人。您的热情参与和无私奉献让这个项目变得更加强大和有意义。没有您的支持，这个项目将无法取得如此巨大的成功。

感谢您无私分享您的时间、知识和技能，让我们能够共同推动开源社区的发展。您的贡献不仅仅是对我个人的支持，更是对整个开源精神的认可和传承。

在未来的道路上，我将继续努力改进和完善这个项目，以回报您的支持与信任。希望我们能够继续保持联系，共同见证这个项目的成长与发展。

再次感谢您的支持与帮助！
