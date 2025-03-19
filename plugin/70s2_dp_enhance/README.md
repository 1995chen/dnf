# 70s2 DP Enhance

70s2专用DP增强插件

## 版本信息
插件开源第二期DP + 嘎嘎香大佬DP

## 镜像版本要求

* dp2插件需要docker镜像版本>=2.1.9.fix1
* game密码必须为默认密码
* 需要配置环境变量SERVER_GROUP_DB=cain
* 只支持希洛克大区

## 如何使用
将本目录下的dp.tgz解压，得到目录结构如下：
```shell
data
├── dp
└── run
```
将dp文件夹中的文件复制到/data/dp/目录下，将run文件夹下的文件复制到/data/run目录下进行覆盖。然后重新启动容器。

## 重启容器
```shell
docker stop dnf
docker start dnf
```

## 特别鸣谢

DNF Docker 架设 3/5群: `一只懒成精的胖子。`
