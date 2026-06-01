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

默认情况下，当指定运行一个大区时，会创建并连接该大区对应的数据库。然而，目前市面上*主流的PVF*只有 160MB 左右，并且*仅开放了希洛克大区*。因此，我们将`SERVER_GROUP`的默认值设置为3（代表希洛克大区）。

大多数服务端以及GM工具连接的是cain数据库。为兼容这种情况，本项目将 `SERVER_GROUP_DB` 默认设为 `cain`，即默认连接 cain 数据库。

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
| DDNS_INTERVAL | DDNS 解析间隔，单位秒 |  | 10 |

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

在这里配置当前大区的数据库root账号以及game账号密码。若未设置主/大区数据库地址，一体镜像会回退到容器内 `127.0.0.1:4000` 的本地 MySQL；server-only 镜像因没有本地 mysqld，启动会直接报错退出并提示设置 `MYSQL_HOST` 和 `MYSQL_PORT`。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| SERVER_GROUP | 大区编号 | 1-6范围的数字 | 3 |
| SERVER_GROUP_DB | 大区数据库 | 所有大区名称 | cain |
| OPEN_CHANNEL | 开启的频道 | 支持配置范围,配置之间用逗号分隔,例如:1-11,12,22-25,51-55 | '11,52' |
| DNF_DB_ROOT_PASSWORD | DNF数据库root密码[当使用独立数据库时,root密码用于初始化数据以及game账号自动化创建、授权] |  | 88888888 |
| DNF_DB_GAME_PASSWORD | DNF数据库game密码，超过 8 位时启动脚本会截断为前 8 位 |  | uu5!^%jg |
| DNF_DB_USER_EXTENDED_QF | 清风版本DNF数据库额外的账号,密码不可设置, 与game保持一致 | 逗号分隔 | supergod,chhappy,cash |
| CLIENT_POOL_SIZE | 服务端启动时分配的客户端缓冲池大小，此配置项影响df_bridge_r和df_channel_r的内存占用 | 3-1000 | 10 |


### 网关配置

`dnf-gate-server` 登录网关相关的环境变量。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| GATE_AES_KEY | dnf-gate-server AES 通讯密钥，需与登录器配置一致 |  | '' |
| GATE_BIND_ADDRESS | dnf-gate-server HTTP 监听地址 |  | 0.0.0.0:5505 |
| GATE_RUST_LOG | dnf-gate-server 日志级别 |  | info,dnf_gate_server=debug |
| GATE_TLS_CERT_PATH | TLS 证书路径，与 `GATE_TLS_KEY_PATH` 同时设置时启用 HTTPS |  | '' |
| GATE_TLS_KEY_PATH | TLS 私钥路径 |  | '' |
| GATE_TLS_BIND_ADDRESS | dnf-gate-server HTTPS 监听地址 |  | 0.0.0.0:5504 |
| GATE_TLS_ONLY | 启用后仅允许 HTTPS 连接，拒绝 HTTP 请求 | true/false | false |
| RSA_PRIVATE_KEY_PATH | RSA 私钥路径 |  | /data/privatekey.pem |
| GAME_SERVER_IP | 游戏服务器 IP，当网关与游戏服务端不在同一台机器时需单独配置 |  | PUBLIC_IP 的值 |
| INITIAL_CERA | 新账号初始点券 |  | 1000 |
| INITIAL_CERA_POINT | 新账号初始代币券 |  | 0 |
| DB_USER | 网关访问数据库的用户名 |  | game |
| DB_NAME | 网关访问的主数据库名 |  | d_taiwan |


### 大区扩展配置

为了简化配置，主数据库和大区数据库的game密码必须一致。game账号密码通过环境变量DNF_DB_GAME_PASSWORD设置，大区数据库root密码通过环境变量DNF_DB_ROOT_PASSWORD配置。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| SERVER_GROUP | 大区编号 | 1-6范围的数字 | 3 |
| SERVER_GROUP_DB | 大区数据库 | 所有大区名称 | cain |
| MAIN_BRIDGE_IP | 主大区 BRIDGE_IP | 主大区的PUBLIC_IP地址 | 127.0.0.1 |
| MAIN_MYSQL_HOST | 主数据库IP地址 |  | '' |
| MAIN_MYSQL_PORT | 主数据库端口号 |  | '' |
| MAIN_MYSQL_ROOT_PASSWORD | 主数据库ROOT账号密码，为空则使用 DNF_DB_ROOT_PASSWORD |  | '' |
| MAIN_MYSQL_GAME_ALLOW_IP | 主数据库GAME账号ALLOW IP |  | '' |
| MYSQL_HOST | 大区数据库的IP地址 |  | '' |
| MYSQL_PORT | 大区数据库的端口号 |  | '' |
| MYSQL_GAME_ALLOW_IP | 大区数据库GAME账号ALLOW IP |  | '' |

本镜像 `SERVER_GROUP_DB` 默认值为 `cain`，因此默认会创建并连接 cain 系列数据库（taiwan_cain 等）。如需连接大区自己的数据库，可以将 `SERVER_GROUP_DB` 设为对应大区名（例如 cain/diregie/siroco），服务端会连接到 taiwan_cain/taiwan_diregie/taiwan_siroco 等对应数据库。若设为空值则使用连接到 `SERVER_GROUP` 对应的大区数据库。

`MAIN_MYSQL_GAME_ALLOW_IP` 和 `MYSQL_GAME_ALLOW_IP` 不设置时，启动脚本从 mysql 的拒绝连接回包里解析 `game` 账号的授权地址。db 镜像的 my.cnf 默认开启 `skip-name-resolve`，解析到的始终是 IP。手动填写时也请使用 IP，不要用主机名。

### 服务端监听端口

| 环境变量名称 | 描述 | 默认值 |
| ------- | ------- | ------- |
| AUCTION_TCP_PORT | df_auction_r 端口 | 30803 |
| BRIDGE_TCP_PORT | df_bridge_r 端口 | 7000 |
| CHANNEL_TCP_PORT | df_channel_r 端口 | 7001 |
| COMMUNITY_TCP_PORT | df_community_r 端口 | 31100 |
| GUILD_TCP_PORT | df_guild_r 端口 | 30403 |
| MANAGER_TCP_PORT | df_manager_r 端口 | 40403 |
| MONITOR_TCP_PORT | df_monitor_r 端口 | 30303 |
| POINT_TCP_PORT | df_point_r 端口，df_game_r 的 cera_auction 也连此端口 | 30603 |
| RELAY_TCP_PORT | df_relay_r 端口，不同大区的端口不同 | 7<大区>00 |
| DBMW_GUILD_TCP_PORT | dbmw_guild 端口 | 20403 |
| DBMW_MNT_TCP_PORT | dbmw_mnt 端口 | 20203 |
| DBMW_STAT_TCP_PORT | dbmw_stat 端口 | 20303 |
| COSERVER_UDP_PORT | df_coserver_r 端口，df_game_r 的 doublecheck 也连此端口 | 30703 |
| STATICS_UDP_PORT | df_statics_r 端口 | 30503 |
| ZERGSVR_PORT | zergsvr 端口 | 9000 |
| SECAGENT_CHANNEL_NUM | secagent 最大频道数 | 12 |
| MAIN_DB_PROXY_PORT | 主库 proxy 本机监听端口 | 3307 |
| SG_DB_PROXY_PORT | 大区库 proxy 本机监听端口 | 3306 |

### 等待 MySQL 启动就绪

使用本地或远程数据库时，启动脚本会调用 `wait_for_mysql.sh` 轮询 MySQL，直到可连通再做 `GRANT` 和库初始化。以下环境变量控制等待策略。

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| WAIT_FOR_MYSQL_MAX_RETRIES | 探活最大重试次数 |  | 240 |
| WAIT_FOR_MYSQL_RETRY_INTERVAL | 每次重试间隔秒数 |  | 2 |

默认 240 × 2 = 480 秒总超时，覆盖冷启动 mysqld 初始化 datadir 较慢的场景。若每次都触发 `mysqladmin --connect-timeout=3` 的超时等待，则总超时为 240 × (3 + 2) = 1200 秒。

### 性能配置

容器启动时读取 cgroup 的 RAM 与 CPU 限制，自动选择一个性能配置并调整 jemalloc `MALLOC_CONF`、`CLIENT_POOL_SIZE` 和 MySQL `/etc/my.cnf`。需要时可通过环境变量覆盖。

#### RAM

| RAM | 性能配置 | 别名 |
| ------- | ------- | ------- |
| < 4 GiB | nano | low |
| 4–8 GiB | micro | |
| 8–16 GiB | small | |
| 16–32 GiB | medium | balanced |
| 32–128 GiB | large | |
| ≥ 128 GiB | xlarge | high |

#### CPU

CPU 数量影响以下参数：
- jemalloc `narenas`：按进程架构 (32 位/64 位) 分别计算。nano/micro 为 min(cpu, cap)；针对 small 及以上配置，32 位进程为 min(cpu×2, cap)，64 位为 min(cpu×4, cap)
- MySQL `thread_cache_size`：取 max(性能配置, cpu×2)
- MySQL 5.7+ `innodb_buffer_pool_size > 1G` 时按 CPU 数设置 `innodb_buffer_pool_instances`

#### 环境变量

| 环境变量名称 | 描述 | 可选参数 | 默认值 |
| ------- | ------- | ------- | ------- |
| AUTO_TUNE | 自动选择性能配置开关，关闭后跳过自动选择，但自定义性能参数仍然有效 | true/false | true |
| TUNE_PROFILE | 指定性能配置 | nano/micro/small/medium/large/xlarge 或<br>low/balanced/high | |
| TUNE_VERBOSE | 输出性能配置详细日志 | true/false | false |
| MALLOC_CONF | jemalloc 全局默认配置，作为 `MALLOC_CONF_32` 与 `MALLOC_CONF_64` 未显式设置时的默认值。设置为空则表示使用 jemalloc 内置默认值 |  | |
| MALLOC_CONF_32 | 32 位进程的 jemalloc 配置，优先级高于 `MALLOC_CONF` |  | |
| MALLOC_CONF_64 | 64 位进程的 jemalloc 配置，优先级高于 `MALLOC_CONF` |  | |
| TUNE_MYSQL_KEY_BUFFER_SIZE | 覆盖 `key_buffer_size` | | |
| TUNE_MYSQL_TABLE_OPEN_CACHE | 覆盖 `table_open_cache`，MySQL 5.0 会覆盖 `table_cache` | | |
| TUNE_MYSQL_SORT_BUFFER_SIZE | 覆盖 `sort_buffer_size` | | |
| TUNE_MYSQL_READ_BUFFER_SIZE | 覆盖 `read_buffer_size` | | |
| TUNE_MYSQL_READ_RND_BUFFER_SIZE | 覆盖 `read_rnd_buffer_size` | | |
| TUNE_MYSQL_THREAD_CACHE_SIZE | 覆盖 `thread_cache_size` | | |
| TUNE_MYSQL_MAX_CONNECTIONS | 覆盖 `max_connections` | | |
| TUNE_MYSQL_MAX_ALLOWED_PACKET | 覆盖 `max_allowed_packet` | | |
| TUNE_MYSQL_QUERY_CACHE_SIZE | 覆盖 `query_cache_size`，只对 MySQL 5.0 生效 | | |
| TUNE_MYSQL_INNODB_BUFFER_POOL_SIZE | 覆盖 `innodb_buffer_pool_size`，只对 MySQL 5.7 生效 | | |

参数优先级，从高到低：
1. 自定义环境变量 `MALLOC_CONF_32`、`MALLOC_CONF_64`，以及 `CLIENT_POOL_SIZE`、`TUNE_MYSQL_*`
2. 全局默认 `MALLOC_CONF`（仅在 MALLOC_CONF_32或 MALLOC_CONF_64 未设置时生效）
3. 自定义性能配置 `TUNE_PROFILE`
4. `AUTO_TUNE=true` 自动选择性能配置
5. nano 性能配置

#### 各性能配置下的 jemalloc 参数

| key | nano | micro | small | medium | large | xlarge |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| narenas (32 位) | min(cpu,2) | min(cpu,4) | min(cpu×2,8) | min(cpu×2,16) | min(cpu×2,64) | min(cpu×2,512) |
| narenas (64 位) | min(cpu,2) | min(cpu,4) | min(cpu×4,8) | min(cpu×4,32) | min(cpu×4,128) | min(cpu×4,1024) |
| lg_tcache_max | 13 | 14 | 15 | 16 | 17 | 18 |
| dirty_decay_ms | 1000 | 3000 | 10000 | 20000 | 30000 | 60000 |
| muzzy_decay_ms | 500 | 1000 | 5000 | 10000 | 30000 | 60000 |
| background_thread | false | false | true | true | true | true |
| retain | false | false | true | true | true | true |
| thp | never | never | never | never | default | default |
| metadata_thp | disabled | disabled | disabled | disabled | auto | auto |

#### 各性能配置下的 MySQL 参数

| key | nano | micro | small | medium | large | xlarge |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| key_buffer_size | 64M | 96M | 128M | 192M | 256M | 384M |
| table_open_cache (5.7) / table_cache (5.0) | 128 | 256 | 512 | 1024 | 1536 | 2048 |
| sort_buffer_size | 512K | 1M | 1M | 2M | 4M | 4M |
| read_buffer_size | 512K | 512K | 1M | 1M | 2M | 2M |
| read_rnd_buffer_size | 1M | 2M | 2M | 4M | 4M | 8M |
| myisam_sort_buffer_size | 16M | 32M | 32M | 64M | 64M | 128M |
| thread_cache_size | 8 | 16 | 32 | 64 | 128 | 256 |
| max_connections | 4096 | 4096 | 4096 | 4096 | 4096 | 4096 |
| max_allowed_packet | 1M | 4M | 16M | 32M | 64M | 64M |
| query_cache_type (5.0) | 1 | 1 | 1 | 1 | 1 | 1 |
| query_cache_size (5.0) | 8M | 16M | 32M | 64M | 128M | 128M |
| innodb_buffer_pool_size (5.7+) | 64M | 128M | 256M | 8% RAM | 10% RAM | 12% RAM |
| innodb_buffer_pool_instances (5.7+, pool>1G) | 1 | 1 | 1 | min(cpu,8) | min(cpu,16) | min(cpu,16) |

#### 各性能配置下的 CLIENT_POOL_SIZE

| 性能配置 | nano | micro | small | medium | large | xlarge |
| ------- | ------- | ------- | ------- | ------- | ------- | ------- |
| CLIENT_POOL_SIZE | 10 | 30 | 100 | 300 | 600 | 1000 |

## docker-compose部署[群晖推荐]

### 基本部署

[点击查看部署文件](../deploy/dnf/docker-compose/basic/docker-compose.yaml)

### 开启多个频道

[点击查看部署文件](../deploy/dnf/docker-compose/multi_channel/docker-compose.yaml)

### 端库分离

游戏服务端与MySQL分别部署在独立容器中。

[点击查看镜像 tag 说明](./PrepareLinux.md#镜像-tag-说明)  
[点击查看部署文件](../deploy/dnf/docker-compose/standalone_mysql/docker-compose.yaml)

### 多大区部署

当你有多台云服务器可以分别在不同的云服务器运行三个大区。

[卡恩-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/cain.yaml)

[狄瑞吉-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/diregie.yaml)

[希洛克-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/siroco.yaml)

或者你只有一台云服务器也可以同时开启三个大区，参考如下部署方式：

[卡恩/狄瑞吉/希洛克-点击查看部署文件](../deploy/dnf/docker-compose/multi_server_group/combine_server_group.yaml)

### docker 服务管理

```shell
docker exec dnf s6-rc-db list all          # 查看全部服务
docker exec dnf s6-svstat /run/service/X   # 查看单个服务状态
docker exec dnf s6-svc -u /run/service/X   # 启动服务
docker exec dnf s6-svc -d /run/service/X   # 停止服务
docker exec dnf s6-svc -r /run/service/X   # 重启服务
```

## k8s部署

[最新的K8S部署方式](../deploy/dnf/k8s-deploy/00-1开始一定要看前期准备.md)

[2.1.5版本以前部署文档](Kubernetes.md)

## 定时任务与数据库备份恢复

容器内置 `scheduler` 定时任务，可通过环境变量控制任务开关以及触发间隔时间。

### 定时任务

| 定时任务 | 默认间隔 | 任务开关 | 说明 |
|---|---|---|---|
| 定期创建拍卖行数据表 | `AUCTION_TABLE_INTERVAL=3600` | 常开 | 按月创建拍卖行和金币寄售当月和下月的数据表 |
| 定期更新 geo ip 白名单 | `GEO_ALLOW_INTERVAL=3600` | 常开 | 把容器 IP 和网关 IP 加入 `d_taiwan.geo_allow` |
| 定期清理 core dump 文件 | `CORE_CLEAN_INTERVAL=86400` | 常开 | 定期删除 `/home/neople` 下的 core 文件 |
| 定期清理拍卖行旧数据表 | `AUCTION_RETENTION_INTERVAL=86400` | `AUCTION_RETENTION_MONTHS`，默认为 0 (关闭) | 清理超出数量的拍卖行旧数据表 |
| 定期备份数据库全量数据 | `DB_BACKUP_INTERVAL=86400` | `DB_BACKUP_ENABLE`，默认 false | 见下方"数据库备份" |

### 环境变量

| 环境变量名称 | 默认值 | 说明 |
|---|---|---|
| `SCHEDULER_TICK` | `60` | 定时任务循环间隔时间，单位秒 |
| `AUCTION_TABLE_INTERVAL` | `3600` | 拍卖行数据表创建间隔时间，单位秒 |
| `GEO_ALLOW_INTERVAL` | `3600` | geo ip 白名单更新间隔时间，单位秒 |
| `CORE_CLEAN_INTERVAL` | `86400` | core 清理间隔间隔，单位秒 |
| `AUCTION_RETENTION_INTERVAL` | `86400` | 旧拍卖表清理间隔时间，单位秒 |
| `AUCTION_RETENTION_MONTHS` | `0` | 拍卖行数据表的保留数量，0 表示不清理。设为 6 则保留最近 6 个月的表 |
| `DB_BACKUP_INTERVAL` | `86400` | 数据库备份间隔时间，单位秒 |
| `DB_BACKUP_ENABLE` | `false` | 设为 `true` 启用自动备份 |
| `DB_BACKUP_KEEP` | `7` | 需要保留的备份文件数量 |
| `DB_BACKUP_DIR` | `/data/backup` | 数据库自动备份目录 |
| `DB_RESTORE_CONFIRM` | 空 | 数据库确认恢复开关，见下方“数据库恢复” |
| `AUCTION_TABLE_RUN_ON_START` | `true` | 启动后是否立刻创建拍卖表 |
| `GEO_ALLOW_RUN_ON_START` | `true` | 启动后是否立刻更新 geo ip 白名单 |
| `CORE_CLEAN_RUN_ON_START` | `false` | 启动后是否立刻清理 core dump 文件 |
| `AUCTION_RETENTION_RUN_ON_START` | `false` | 启动后是否立刻清理旧拍卖表 |
| `DB_BACKUP_RUN_ON_START` | `false` | 启动后是否立刻备份数据库 |

旧拍卖行清理和数据库备份默认关闭，需要时用环境变量开启。
`<任务>_RUN_ON_START` 取值为 `true / false`。设为 `false` 的任务在容器启动后不会立刻执行，而是等到下次触发时再执行。

### geo 白名单

如果连接频道时网络中断，多半是 geo 拦截。可以从频道日志里找到被拦截的 IP，加进白名单后重启服务即可。被拦截时日志类似：

```
[16:02:51] bool RestrictGeolocation::isAllow(std::string, std::string)(90): [Taiwan, GeoIP] Fail Account:18000000, IP:192.168.48.1, CountryCode:
```

上面被拦截的 IP 是 192.168.48.1，在 `user-script.sh` 里加入：

```shell
mysql -h $CUR_MAIN_DB_HOST -P $CUR_MAIN_DB_PORT -u game -p$DNF_DB_GAME_PASSWORD <<EOF
  insert ignore into d_taiwan.geo_allow values ('192.168.48.1', "*", "2016-04-09 23:53:04");
EOF
```

### 数据库备份

开启时，容器会使用 `mysqldump` 导出所有非系统库数据，之后用 gzip 压缩保存到 `DB_BACKUP_DIR`。文件名类似 `dnf-20260531-143000.sql.gz`，文件最多保留最近的 `DB_BACKUP_KEEP` 份。备份时间从容器启动时开始计算，每隔 `DB_BACKUP_INTERVAL` 触发一次。

若要启动数据库自动备份功能，可在 docker-compose.yml 中设置以下环境变量来开启:

```yaml
environment:
  - DB_BACKUP_ENABLE=true
  - DB_BACKUP_KEEP=7
  # 可选：调整备份间隔时间和目录，间隔单位为秒
  # - DB_BACKUP_INTERVAL=86400
  # - DB_BACKUP_DIR=/data/backup
```

### 数据库恢复

若要恢复备份的数据库，可进入容器执行 `restore-db.sh`。考虑到此操作比较危险，脚本默认只会显示将要使用的备份文件以及被还原的库。若要真正触发还原，需设置 `DB_RESTORE_CONFIRM=yes`。

将要使用的备份文件以及被还原的库：

```bash
docker exec dnf /home/template/init/scheduler/restore-db.sh latest
```

确认无误后再执行：

```bash
docker exec -e DB_RESTORE_CONFIRM=yes dnf /home/template/init/scheduler/restore-db.sh latest
```

脚本参数：

- `latest`：默认值，使用最新备份数据
- 文件名：如 `dnf-20260531-143000.sql.gz`，从 `DB_BACKUP_DIR` 查找指定备份数据
- 绝对路径：如 `/data/backup/dnf-20260531-143000.sql.gz`

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
