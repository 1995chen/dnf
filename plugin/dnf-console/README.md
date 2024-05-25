# dnf-console

## github doc
https://github.com/localhostjason/dnf-console

## 如何使用
将本目录下的dnf-console.tgz、dnf-console.conf复制到/data/data/conf.d目录下。

## 映射端口
本插件默认会使用容器的8088端口，我们需要在docker的启动命令中加入端口映射，例如: -p 882:8088/tcp

## 清除容器
```shell
docker stop dnf
docker rm dnf
```

## 重新启动
我们将8088端口映射后，用新的启动命令启动，假设我们使用882端口，那么启动命令如下：
```shell
docker run -d -e PUBLIC_IP=x.x.x.x -e WEB_USER=root -e WEB_PASS=123456 -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gmuser -e GM_PASSWORD=gmpass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 2000:180 -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 882:8088/tcp -p 7001:7001/tcp -p 7001:7001/udp -p 10011:10011/tcp -p 11011:11011/udp -p 10052:10052/tcp -p 11052:11052/udp -p 7200:7200/tcp -p 7200:7200/udp -p 2311-2313:2311-2313/udp --privileged=true --cap-add=NET_ADMIN --hostname=dnf --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g --name=dnf 1995chen/dnf:centos5-2.1.4.fix1
```
