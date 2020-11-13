docker run -d -e IP=x.x.x.x -v /data/mysql:/var/lib/mysql -v /data/root:/root -v /data/neople:/home/neople --net=host --privileged=true --memory=8g --oom-kill-disable --shm-size=8g 1995chen/dnf:85
