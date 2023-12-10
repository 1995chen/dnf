# 构建基础镜像 哈哈哈哈
docker build -f $(pwd)/build/DnfBase -t 1995chen/centos:6.9 $(pwd)
# 构建DNF服务
docker build -f $(pwd)/build/Dockerfile -t 1995chen/dnf:latest $(pwd)
