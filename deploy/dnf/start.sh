#! /bin/bash

# 执行初始化, 该步骤放在前台执行,执行后自动退出
docker-compose up init-dnf
# 启动dnf, 该步骤放在后台执行
docker-compose up -d dnf
