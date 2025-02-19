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
  # 启动netbird服务
  service netbird stop || true
  service netbird start || true
  # 等待netbird启动
  while true;
  do
    nb_status=$(service netbird status 2>/dev/null || true)
    ddns_ip=$(/data/monitor_ip/get_ddns_ip.sh 2>/dev/null || true)
    if [ "$nb_status" != "Running" ] ; then
      echo "netbird service status is $nb_status, restart and sleep"
      service netbird stop || true
      service netbird start || true
    else
      echo "netbird service start success, break"
      break
    fi
    # 等待
    sleep 5
  done
  sleep 5
  NB_FOREGROUND_MODE=false netbird up
else
    echo "no need to start netbird"
fi
# 等待5秒后退出
sleep 5
