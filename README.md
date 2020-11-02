# 地下城与勇士容器版本

##  注意事项
不支持Windows

## 关闭防火墙
```shell
# 关闭宿主机防火墙
# Centos5-6
service iptables stop
chkconfig iptables off
# Centos7
systemctl disable firewalld
systemctl stop firewalld
systemctl disable firewalld.service
systemctl stop firewalld.service
# ubuntu
sudo ufw disable
```

## Centos需要关闭SELINUX（建议永久关闭）
```shell
修改/etc/sysconfig/selinux文件
将文件内的SELINUX设置为disabled就可以了。记得重启服务器。
```

## 开启SWAP(机器内存大于8G可忽略这一步)
```shell
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
mkswap /var/swap.1
swapon /var/swap.1
sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
```

## 镜像拉取

```shell
docker pull 1995chen/dnf:85.1
```

## 启动
```shell
docker run -d -e IP=你的外网IP -v /data/root:/root -v /data/neople:/home/neople --net=host --privileged=true --memory=8g --oom-kill-disable --shm-size=8g 1995chen/dnf:85.1
```

## 接下来的操作
按照容器内readme操作进行，里面有修改IP的脚本，把IP改为服务器公网IP就可以了。然后启动数据库服务，在数据库中把那个db_ip也改成公网IP。
接下来就是启动游戏服务了，亲测可用，不喜勿喷。

## 申明
虽然支持外网，但是千万别拿来开服。只能拿来学习使用
