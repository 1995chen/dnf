# 部署注意事项

## 安装mysql client
CentOS7 安装方式如下:
```shell
yum update -y
rpm -ivh https://repo.mysql.com//mysql57-community-release-el7-11.noarch.rpm
yum install mysql-community-client.x86_64 -y
```

## 修改初始化脚本

修改[初始化脚本](first_init.sh)中的环境变量 DB_ROOT_PWD设置为数据库ROOT密码 DB_IP为数据库IP地址,如果未修改[compose文件](docker-compose.yaml)可以不更改
DB_PORT为数据库暴露的端口,如果未修改[compose文件](docker-compose.yaml)可以不更改

## 运行初始化脚本

cd到deploy/dnf下, 运行[first_init.sh](first_init.sh)

```shell
chmod +x first_init.sh
bash ./first_init.sh
```

## 启动服务

cd到deploy/dnf下, 运行[start.sh](start.sh)

```shell
chmod +x start.sh
bash ./start.sh
```

## 停止服务

cd到deploy/dnf下, 运行[stop.sh](stop.sh)

```shell
chmod +x stop.sh
bash ./stop.sh
```

## 更新版本
替换PVF文件(deploy/dnf/data/Script.pvf)后，重启服务
bash ./stop.sh
bash ./start.sh
