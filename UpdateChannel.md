# 更换频道

## 修改频道配置文件

进入频道配置文件目录
```shell
cd /data/data/conf.d
```

频道配置介绍,默认的频道配置如下:
```shell
# channel 配置,理论上你不应该修改这块配置
[program:channel]
command=/bin/bash -c "/data/channel/start_channel.sh"
directory=/home/neople/channel
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/channel.log
redirect_stderr=true
depend=bridge

# ch.11频道[普通频道]配置
[program:game_siroco11]
command=/bin/bash -c "/data/channel/start_siroco.sh 11 3" # 启动命令 11为频道编号 3为普通频道 默认会自动使用10011端口
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_siroco11.log # 日志存放位置
redirect_stderr=true
depend=zergsvr

# ch.52频道[决斗场频道]配置
[program:game_siroco52]
command=/bin/bash -c "/data/channel/start_siroco.sh 52 5"  # 启动命令 52为频道编号 5为决斗场频道 默认会自动使用10052端口
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_siroco52.log # 日志存放位置
redirect_stderr=true
depend=game_siroco11

[group:dnf_channel]
programs=channel,game_siroco11,game_siroco52 # 需要在这里注册所有频道
priority=999
```

# 新增频道

这里我们假设新增22频道,配置文件变更如下:
```shell
[program:channel]
command=/bin/bash -c "/data/channel/start_channel.sh"
directory=/home/neople/channel
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/channel.log
redirect_stderr=true
depend=bridge

[program:game_siroco11]
command=/bin/bash -c "/data/channel/start_siroco.sh 11 3"
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_siroco11.log
redirect_stderr=true
depend=channel

[program:game_siroco22]
command=/bin/bash -c "/data/channel/start_siroco.sh 22 3"
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_siroco22.log
redirect_stderr=true
depend=channel

[program:game_siroco52]
command=/bin/bash -c "/data/channel/start_siroco.sh 52 5"
directory=/home/neople/game
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=/data/log/game_siroco52.log
redirect_stderr=true
depend=channel

[group:dnf_channel]
programs=channel,game_siroco11,game_siroco52,game_siroco22
priority=999
```
最终要的是我们需要将新增的game_siroco52加入到[group:dnf_channel]组内!!!

## 开放端口

由于我们新增了22频道，频道程序会自动使用10022端口，因此我们需要停止并移除docker容器，然后新增端口映射后再次启动
```shell
# 停止docker容器
docker stop dnf
# 移除docker容器
docker rm dnf
# 启动docker容器
# 11022:11022/udp参数，来开放10022频道端口
docker run -d -e PUBLIC_IP=x.x.x.x -e WEB_USER=root -e WEB_PASS=123456 -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gmuser -e GM_PASSWORD=gmpass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 2000:180 -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 7001:7001/tcp -p 7001:7001/udp -p 10011:10011/tcp -p 11011:11011/udp -p 10022:10022/tcp -p 11022:11022/udp -p 10052:10052/tcp -p 11052:11052/udp -p 7200:7200/tcp -p 7200:7200/udp -p 2311-2313:2311-2313/udp --privileged=true --cap-add=NET_ADMIN --hostname=dnf --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g --name=dnf 1995chen/dnf:centos5-2.1.4.fix1
```
这里启动命令我们新增了-p 10022:10022/tcp -p 11022:11022/udp,该参数的作用就是映射新的频道端口。
如果你开的是33频道，拿对应的端口参数就是:-p 10033:10033/tcp -p 11033:11033/udp。
