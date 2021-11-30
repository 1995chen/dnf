# 部署注意事项

## 关闭防火墙

```shell
systemctl disable firewalld
systemctl stop firewalld
systemctl disable firewalld.service
systemctl stop firewalld.service
```

## 关闭SELINUX

```shell
修改/etc/sysconfig/selinux文件
将文件内的SELINUX设置为disabled就可以了. 记得重启服务器.
```

## 开启swap

```shell
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8000
mkswap /var/swap.1
swapon /var/swap.1
sed -i '$a /var/swap.1 swap swap default 0 0' /etc/fstab
```

## 启动服务

cd到deploy/dnf下, 运行[start.sh](start.sh)

```shell
./start.sh
```

## 停止服务

cd到deploy/dnf下, 运行[stop.sh](stop.sh)

```shell
./stop.sh
```

## 更新版本

替换PVF文件(deploy/dnf/data/Script.pvf)后，重启服务
注意PVF要配套相应的[等级补丁](../../build/DNF/df_game_r)
```shell
./stop.sh 
./start.sh
```

## 申明

虽然支持外网, 但是千万别拿来开服. 只能拿来学习使用!!!!!!  
虽然支持外网, 但是千万别拿来开服. 只能拿来学习使用!!!!!!  
虽然支持外网, 但是千万别拿来开服. 只能拿来学习使用!!!!!!  
