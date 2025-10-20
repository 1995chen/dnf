# 详细部署文档

## 大区代号映射表

以下表格列出了官方文档中明确提及的大区代号和大区名称:
| 大区代号 | 大区名称 | 描述 | 大区主数据库 |
| ------- | ------- | ------- | ------- |
| 1 | cain | 卡恩 | taiwan_cain |
| 2 | diregie | 狄瑞吉 | taiwan_diregie |
| 3 | siroco | 希洛克 | taiwan_siroco |
| 4 | prey | 普雷 | taiwan_prey |
| 5 | casillas | 卡西利亚斯 | taiwan_casillas |
| 6 | hilder | 赫尔德 | taiwan_hilder |

```
默认情况下，当指定运行一个大区时，该项目会创建并连接该大区对应的数据库。
```

然而，目前市面上`主流的PVF`只有160MB左右，并且`仅开放了希洛克大区`。因此，我们将SERVER_GROUP的默认值设置为3（代表希洛克大区）。

此外，大多数服务端以及GM工具连接的是cain数据库。为了适配这种情况，我们可以通过设置环境变量SERVER_GROUP_DB=cain来明确指定使用卡恩数据库。否则可能会造成部分GM工具无法使用等问题。

## 环境变量概述

### 服务外网IP配置

#### 明确指定外网IP

第一优先级，当配置了PUBLIC_IP时，其他的低优先级的外网IP配置均失效。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| PUBLIC_IP | 当前机器IP地址 |  | '' |

#### 自动获得外网IP(仅云服务器可用)

第二优先级，当配置了AUTO_PUBLIC_IP时，其他的低优先级的外网IP配置均失效。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| AUTO_PUBLIC_IP | 自动获取公网地址 | true/false | false |

#### DDNS配置

第三优先级，该设置将自动获取域名的IP地址作为服务的外网访问地址。若要使用域名的IP地址解析作为服务的公网IP，请设置DDNS_ENABLE=true，并指定DDNS_DOMAIN为您的域名，此时其他低优先级的外网IP配置均失效。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| DDNS_ENABLE | DDNS开关 | true/false | false |
| DDNS_DOMAIN | DDNS域名 |  | '' |

#### Netbird配置

次低优先级，会使用Netbird虚拟IP作为外网IP，缺点是所有客户端均需要加入Netbird虚拟网络。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| NB_MANAGEMENT_URL | Netbird服务器地址 |  | '' |
| NB_SETUP_KEY | Netbird初始化KEY |  | '' |


#### Tailscale配置

最低优先级，会使用Tailscale虚拟IP作为外网IP，缺点是所有客户端均需要加入Tailscale虚拟
网络。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| TS_LOGIN_SERVER | Tailscale服务器地址 |  | 'https://controlplane.tailscale.com' |
| TS_AUTH_KEY | Tailscale初始化KEY |  | '' |


### 基本配置

在这里配置当前大区的数据库root账号以及game账号密码。在没有配置主数据库以及大区数据库的情况下，会自动使用容器内部MYSQL数据库。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| SERVER_GROUP | 大区编号 | 1-6范围的数字 | 3 |
| SERVER_GROUP_DB | 大区数据库 | 所有大区名称 | cain |
| OPEN_CHANNEL | 开启的频道 | 支持配置范围,配置之间用逗号分隔,例如:1-11,12,22-25,51-55 | '11,52' |
| DNF_DB_ROOT_PASSWORD | DNF数据库root密码[当使用独立数据库时,root密码用于初始化数据以及game账号自动化创建、授权] |  | '' |
| DNF_DB_GAME_PASSWORD | DNF数据库game密码[必须8位] |  | '' |
| CLIENT_POOL_SIZE | 服务端启动时分配的客户端缓冲池大小，此配置项影响df_bridge_r和df_channel_r的内存占用 | 3-1000 | 10 |

### 进程监控管理页面配置

配置访问Supervisor进程管理页面所需的用户名密码。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| WEB_USER | supervisor web页面用户名 |  | root |
| WEB_PASS | supervisor web页面密码 |  | 123456 |


### 统一网关配置

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| GM_ACCOUNT | GM管理员账号 | 不能有特殊字符 | gmuser |
| GM_PASSWORD | GM管理员密码 | 不能有特殊字符 | gmpass |
| GM_CONNECT_KEY | GM连接KEY[自定以密钥请使用网关生成的密钥，因为密钥有格式限制，不符合格式的密钥会导致登录器一致卡在网关连接那里] |  | 763WXRBW3PFTC3IXPFWH |
| GM_LANDER_VERSION | GM登录器版本 |  | 20180307 |

### 大区扩展配置

为了简化配置，主数据库和大区数据库的game密码必须一致。game账号密码通过环境变量DNF_DB_GAME_PASSWORD设置，大区数据库root密码通过环境变量DNF_DB_ROOT_PASSWORD配置。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| SERVER_GROUP | 大区编号 | 1-6范围的数字 | 3 |
| SERVER_GROUP_DB | 大区数据库 | 所有大区名称 | cain |
| MAIN_BRIDGE_IP | 主大区 BRIDGE_IP | 主大区的PUBLIC_IP地址 | 127.0.0.1 |
| MAIN_MYSQL_HOST | 主数据库IP地址 |  | '' |
| MAIN_MYSQL_PORT | 主数据库端口号 |  | '' |
| MAIN_MYSQL_ROOT_PASSWORD | 主数据库ROOT账号密码 |  | '' |
| MAIN_MYSQL_GAME_ALLOW_IP | 主数据库GAME账号ALLOW IP |  | '' |
| MYSQL_HOST | 大区数据库的IP地址 |  | '' |
| MYSQL_PORT | 大区数据库的端口号 |  | '' |
| MYSQL_GAME_ALLOW_IP | 大区数据库GAME账号ALLOW IP |  | '' |

默认情况下，系统会创建并连接到相应大区的数据库。若需要连接到其他大区的数据库，需设置环境变量SERVER_GROUP_DB为相应大区的名称（例如cain/diregie/siroco）。在这种情况下，服务内部也会连接到 taiwan_cain/taiwan_diregie/taiwan_siroco 等大区的数据库。

## docker-compose部署[群晖推荐]

### 基本部署

[点击查看部署文件](../deploy/dnf/docker-compose/basic/docker-compose.yaml)

### 开启多个频道

[点击查看部署文件](../deploy/dnf/docker-compose/multi_channel/docker-compose.yaml)

### 站库分离

[点击查看部署文件](../deploy/dnf/docker-compose/standalone_mysql/docker-compose.yaml)

### 多大区部署

当你有多台云服务器可以分别在不同的云服务器运行三个大区。

[卡恩-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/cain.yaml)

[狄瑞吉-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/diregie.yaml)

[希洛克-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/siroco.yaml)

或者你只有一台云服务器也可以同时开启三个大区，参考如下部署方式：

[卡恩/狄瑞吉/希洛克-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/combine_server_group.yaml)

如果发现连接频道时网络中断的问题，大概率是GEO拦截，需要从频道的log中找到拦截的IP地址，并修改data/daily_job/user_daily_script.sh脚本，
添加白名单并重启服务。当发生拦截时，会产生类似以下的日志：

[16:02:51] bool RestrictGeolocation::isAllow(std::string, std::string)(90): [Taiwan, GeoIP] Fail Account:18000000, IP:192.168.48.1, CountryCode:

上述日志被拦截的IP地址为192.168.48.1,则添加如下命令。
```shell
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
  insert into d_taiwan.geo_allow values ('192.168.48.1', "*", "2016-04-09 23:53:04");
EOF
```

## k8s部署

[最新的K8S部署方式](../deploy/dnf/k8s-deploy/00-1开始一定要看前期准备.md)

[2.1.5版本以前部署文档](Kubernetes.md)

## 各大区Relay对应端口

| 大区编号 | 协议 | 端口号 |
| ------- | ------- | ------- |
| 1 | TCP | 7100 |
| 1 | UDP | 7100 |
| 2 | TCP | 7200 |
| 2 | UDP | 7200 |
| 3 | TCP | 7300 |
| 3 | UDP | 7300 |
| N | TCP | 7N00 |
| N | UDP | 7N00 |

其中N为1-6之间的数字。

## 各大区Stun对应端口

| 大区编号 | 协议 | 端口号 |
| ------- | ------- | ------- |
| 1 | TCP | 2111-2113 |
| 1 | UDP | 2111-2113 |
| 2 | TCP | 2211-2213 |
| 2 | UDP | 2211-2213 |
| 3 | TCP | 2311-2313 |
| 3 | UDP | 2311-2313 |
| N | TCP | 2N11-2N13 |
| N | UDP | 2N11-2N13 |

其中N为1-6之间的数字。

## 各大区频道对应端口

| 大区编号 | 频道 | 协议 | 端口号 |
| ------- | ------- | ------- | ------- |
| 1 | 6 | TCP | 10006 |
| 1 | 6 | UDP | 11006 |
| 1 | 7 | TCP | 10007 |
| 1 | 7 | UDP | 11007 |
| 1 | 11-39 | TCP | 10011-10039 |
| 1 | 11-39 | UDP | 11011-11039 |
| 1 | 52-56 | TCP | 10052-10056 |
| 1 | 52-56 | UDP | 11052-11056 |
| 2 | 6 | TCP | 20006 |
| 2 | 6 | UDP | 21006 |
| 2 | 7 | TCP | 20007 |
| 2 | 7 | UDP | 21007 |
| 2 | 11-39 | TCP | 20011-20039 |
| 2 | 11-39 | UDP | 21011-21039 |
| 2 | 52-56 | TCP | 20052-20056 |
| 2 | 52-56 | UDP | 21052-21056 |
| 3 | 6 | TCP | 30006 |
| 3 | 6 | UDP | 31006 |
| 3 | 7 | TCP | 30007 |
| 3 | 7 | UDP | 31007 |
| 3 | 11-39 | TCP | 30011-30039 |
| 3 | 11-39 | UDP | 31011-31039 |
| 3 | 52-56 | TCP | 30052-30056 |
| 3 | 52-56 | UDP | 31052-31056 |
| N | 6 | TCP | N0006 |
| N | 6 | UDP | N1006 |
| N | 7 | TCP | N0007 |
| N | 7 | UDP | N1007 |
| N | 11-39 | TCP | N0011-N0039 |
| N | 11-39 | UDP | N1011-N1039 |
| N | 52-56 | TCP | N0052-N0056 |
| N | 52-56 | UDP | N1052-N1056 |

其中N为1-6之间的数字。目前发现cain服没有52频道。数据库数据或PVF可能需要更近一步适配，欢迎大家提PR。
