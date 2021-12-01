# 懒人启动方式
# 自定义其中环境变量所有的环境变量都是可以改的
# 创建目录，用于存放数据
mkdir -p /data
# 初始化[改脚本运行时间较长,可能要10多分钟,主要是将sql导入数据库]
# 将root密码重置为DNF_DB_ROOT_PASSWORD
docker run -e DNF_DB_ROOT_PASSWORD=88888888 -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data 1995chen/dnf:stable /bin/bash /home/template/init/init.sh

# 遇到CoreDump就多跑几次,机器内存不足容易OOM建议上8G的交换空间
# 使用该DNF_DB_ROOT_PASSWORD密码给game账户赋予权限,设置其只允许本地访问增加安全性
docker run -d -e PUBLIC_IP=x.x.x.x -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gm_user -e GM_PASSWORD=gm_pass -v /data/log:/home/neople/game/log -v /data/mysql:/var/lib/mysql -v /data/data:/data -p 3000:3306/tcp -p 7600:7600/tcp -p 881:881/tcp -p 20303:20303/tcp -p 20303:20303/udp -p 20403:20403/tcp -p 20403:20403/udp -p 40403:40403/tcp -p 40403:40403/udp -p 7000:7000/tcp -p 7000:7000/udp -p 7001:7001/tcp -p 7001:7001/udp -p 7200:7200/tcp -p 7200:7200/udp -p 10011:10011/tcp -p 31100:31100/tcp -p 30303:30303/tcp -p 30303:30303/udp -p 30403:30403/tcp -p 30403:30403/udp -p 10052:10052/tcp -p 20011:20011/tcp -p 20203:20203/tcp -p 20203:20203/udp -p 30703:30703/udp -p 11011:11011/udp -p 2311-2313:2311-2313/udp -p 30503:30503/udp -p 11052:11052/udp --cpus=1 --memory=1g --memory-swap=-1 --shm-size=8g 1995chen/dnf:stable
