#! /bin/bash

# 检查Netbird IP
if [ -z "$PUBLIC_IP" ] && [ -n "$NB_SETUP_KEY" ] && [ -n "$NB_MANAGEMENT_URL" ]; then
  # 重新安装netbird service
  if [ -f "/etc/init.d/netbird" ];then
    echo "uninstall old netbird service"
    rm -rf /etc/init.d/netbird
  fi
  echo "install new netbird service"
  cp /home/template/init/netbird/netbird /etc/init.d/
  # 替换变量
  sed -i "s#NB_MANAGEMENT_URL#$NB_MANAGEMENT_URL#g" /etc/init.d/netbird
  echo "starting netbird service[$NB_MANAGEMENT_URL] use setup_key: $NB_SETUP_KEY"
  service netbird start
  # 保持前台运行
  netbird up --foreground-mode --config=/data/netbird/config.json --log-level=info --log-file=/data/log/netbird/netbird.log
else
    echo "no need to start netbird"
    sleep 5
fi
