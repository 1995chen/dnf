# 地下城与勇士容器版本

##  注意事项
不支持Windows!!!

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

## 接下来的操作
在deploy目录下有部署脚本,具体请参考[详细部署流程请](deploy/dnf/deploy.md)

## 申明
虽然支持外网，但是千万别拿来开服。只能拿来学习使用
