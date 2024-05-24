# dnf-console

## 版本信息
dp2.9.0+frida_240418

## 如何使用
将本目录下的dp2.tgz复制到/data/data/dp目录下,然后手动解压dp2.tgz。
解压后目录结构如下:
```shell
dp
├── df_game_r.js
├── df_game_r.lua
├── dp2.tgz
├── frida
├── lib
├── libdp2.so
├── libdp2.xml
├── libGeoIP.so.1
├── libhook.so
├── lua
├── lua2
├── README.md
└── script
```

## 重启容器
```shell
docker stop dnf
docker start dnf
```
