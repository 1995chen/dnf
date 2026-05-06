# 准备部署环境

本指南包含 Docker 安装、seccomp 兼容配置、交换空间配置和防火墙关闭几个部分。如果已完成这些配置，可以跳过。

## 安装 Docker

升级系统

```shell
yum update -y
```

或

```shell
apt-get update && apt-get upgrade -y
```

下载并运行 Docker 安装脚本

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

启动 Docker

```shell
systemctl enable docker
systemctl restart docker
```

<a id="seccomp-profile"></a>
检测 Docker 版本并按需下载 seccomp 兼容配置

Docker 29 及之后版本的默认 seccomp 策略会导致服务端报错 `Could not create a UDP socket : 38`。如果检测到 Docker 主版本大于等于 29，建议提前下载兼容配置文件；低版本 Docker 不需要执行此操作。

```shell
DOCKER_MAJOR_VERSION="$(docker version --format '{{.Server.Version}}' | sed 's/\..*//')"

if [ "$DOCKER_MAJOR_VERSION" -ge 29 ] 2>/dev/null; then
  echo "检测到 Docker ${DOCKER_MAJOR_VERSION}.x，下载 seccomp 兼容配置..."
  mkdir -p /etc/docker
  curl -fsSL https://raw.githubusercontent.com/moby/profiles/refs/tags/seccomp/v0.2.1/seccomp/default.json \
    -o /etc/docker/seccomp-profile-v0.2.1.json
else
  echo "Docker 主版本低于 29，无需下载 seccomp 兼容配置。"
fi
```

关闭防火墙

```shell
systemctl disable firewalld
systemctl stop firewalld
```

关闭 SELinux

```shell
setenforce 0
sed -i "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config
```

## 配置交换空间

当物理内存不足 8GB 时，需要配置交换空间。

创建 Swap 文件

```shell
which /usr/bin/fallocate && /usr/bin/fallocate --length 8GiB /var/swap.1 || /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
mkswap /var/swap.1
swapon /var/swap.1
sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
```

查看 Swap 是否已启用

```shell
sysctl vm.swappiness
```

如果输出的数字不为 0，说明 Swap 已启用，无需额外操作。

如果输出为 0，执行以下命令启用 Swap。值为 100 表示优先使用虚拟内存，值为 0 表示优先使用物理内存。少量玩家场景下体感差异不大。

```shell
sed -i '$a vm.swappiness = 100' /etc/sysctl.conf
```

重启服务器，或执行以下命令使配置生效

```shell
sysctl -p
```

<a id="pull-image"></a>
## 拉取镜像

镜像同时发布到以下仓库，内容完全一致，选择速度最快的即可。

## 镜像 Tag 说明

镜像按 4 层架构发布，每层都有独立的 tag：

| 层级 | 内容 | 用途 |
|------|------|------|
| base | 基础系统依赖 | 基础镜像，无法直接使用 |
| db | MySQL 5.7，CentOS 7 为 MySQL 5.0.95 | 端库分离部署中的数据库镜像 |
| server | 游戏服务端 + MySQL 客户端，不含 MySQL 服务端 | 端库分离部署中的服务端镜像，需连接外部 MySQL |
| full | 完整版镜像，游戏服务端 + 内置 MySQL | 单容器部署 |

各层级的 tag 格式：

| 层级 | Release Latest | Release | Dev Latest | Dev |
|------|---------------|---------|-----------|-----|
| base | `<os>-base-latest` | `<os>-base-<日期>` | `<os>-base-dev-latest` | `<os>-base-dev-<commit>` |
| db | `<os>-db-latest` | `<os>-db-<日期>` | `<os>-db-dev-latest` | `<os>-db-dev-<commit>` |
| server | `<os>-server-qf1031-latest` | `<os>-server-qf1031-<日期>` | `<os>-server-qf1031-dev-latest` | `<os>-server-qf1031-dev-<commit>` |
| full | `<os>-qf1031-latest` | `<os>-qf1031-<日期>` | `<os>-qf1031-dev-latest` | `<os>-qf1031-dev-<commit>` |

其中 `<os>` 为 `debian13`、`alma9`、`ubuntu26`、`centos7` 之一。开发版镜像在每次 push 到 main 分支时生成。

full 镜像提供一组别名 tag：`<os>-full-qf1031-latest`、`<os>-full-qf1031-<日期>`、`<os>-full-qf1031-dev-latest`、`<os>-full-qf1031-dev-<commit>`，别名与主 tag 指向同一镜像。

普通用户只需拉取 full 镜像即可，端库分离场景拉取 server + db 镜像。

以下示例仅列出 full 层 latest tag，其他层级或版本按上表替换 tag 即可。例如：`llnut/dnf:debian13-db-latest`、`llnut/dnf:debian13-server-qf1031-latest`。

<a id="acr-image"></a>
### 阿里云 ACR (中国大陆拉取加速)

```shell
docker pull crpi-0ghho6wxim378ik8.cn-hangzhou.personal.cr.aliyuncs.com/llnut/dnf:debian13-qf1031-latest
docker pull crpi-0ghho6wxim378ik8.cn-hangzhou.personal.cr.aliyuncs.com/llnut/dnf:alma9-qf1031-latest
docker pull crpi-0ghho6wxim378ik8.cn-hangzhou.personal.cr.aliyuncs.com/llnut/dnf:ubuntu26-qf1031-latest
docker pull crpi-0ghho6wxim378ik8.cn-hangzhou.personal.cr.aliyuncs.com/llnut/dnf:centos7-qf1031-latest
```

<a id="docker-hub-image"></a>
### Docker Hub

```shell
docker pull llnut/dnf:debian13-qf1031-latest
docker pull llnut/dnf:alma9-qf1031-latest
docker pull llnut/dnf:ubuntu26-qf1031-latest
docker pull llnut/dnf:centos7-qf1031-latest
```

<a id="ghcr-image"></a>
### ghcr.io

```shell
docker pull ghcr.io/llnut/dnf:debian13-qf1031-latest
docker pull ghcr.io/llnut/dnf:alma9-qf1031-latest
docker pull ghcr.io/llnut/dnf:ubuntu26-qf1031-latest
docker pull ghcr.io/llnut/dnf:centos7-qf1031-latest
```

<a id="quay-image"></a>
### quay.io

```shell
docker pull quay.io/llnut/dnf:debian13-qf1031-latest
docker pull quay.io/llnut/dnf:alma9-qf1031-latest
docker pull quay.io/llnut/dnf:ubuntu26-qf1031-latest
docker pull quay.io/llnut/dnf:centos7-qf1031-latest
```

### 端库分离场景示例

以 Debian 13 为例，需要分别拉取 server 层和 db 层：

```shell
docker pull llnut/dnf:debian13-server-qf1031-latest
docker pull llnut/dnf:debian13-db-latest
```
