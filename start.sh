# 懒人启动方式
# 自定义其中环境变量所有的环境变量都是可以改的

# 初始化[改脚本运行时间较长,可能要10多分钟,主要是将sql导入数据库]
# 将root密码重置为DNF_DB_ROOT_PASSWORD
docker run -e PUBLIC_IP=x.x.x.x -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gm_user -e GM_PASSWORD=gm_pass -v /data/mysql:/var/lib/mysql -v /data:/data --net=host --privileged=true --memory=8g --oom-kill-disable --shm-size=8g 1995chen/dnf:latest /bin/bash /home/template/init/init.sh

# 遇到CoreDump就多跑几次,机器内存不足容易OOM建议上8G的交换空间
# 使用该DNF_DB_ROOT_PASSWORD密码给game账户赋予权限,设置其只允许本地访问增加安全性
docker run -d -e PUBLIC_IP=x.x.x.x -e DNF_DB_ROOT_PASSWORD=88888888 -e GM_ACCOUNT=gm_user -e GM_PASSWORD=gm_pass -v /data/mysql:/var/lib/mysql -v /data:/data --net=host --privileged=true --memory=8g --oom-kill-disable --shm-size=8g 1995chen/dnf:latest
