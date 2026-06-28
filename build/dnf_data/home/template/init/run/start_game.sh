# /bin/bash

# 获得频道传入参数
channel_no=$1
process_sequence=$2
channel_name="$SERVER_GROUP_NAME$channel_no"

echo "channel_name is $channel_name"
echo "prepare to start ch.$channel_no, process_sequence is $process_sequence"
# 等待bridge启动,最多等待30秒
counter=0
while [ $counter -lt 30 ]
do
  if nc -zv $MAIN_BRIDGE_IP 7000 2>&1 | grep succeeded >/dev/null ; then
    echo "bridge 7000 port ready"
    break
  fi
  sleep 2
  ((counter++))
done
# 等待monitor启动,最多等待30秒
counter=0
while [ $counter -lt 30 ]
do
  if nc -zv $CORE_PUBLIC_IP "3${SERVER_GROUP}303" 2>&1 | grep succeeded >/dev/null ; then
    echo "monitor $CORE_PUBLIC_IP:3${SERVER_GROUP}303 port ready"
    break
  fi
  sleep 2
  ((counter++))
done
# 等待guild启动,最多等待30秒
counter=0
while [ $counter -lt 30 ]
do
  if nc -zv $CORE_PUBLIC_IP "3${SERVER_GROUP}403" 2>&1 | grep succeeded >/dev/null ; then
    echo "guild $CORE_PUBLIC_IP:3${SERVER_GROUP}403 port ready"
    break
  fi
  sleep 2
  ((counter++))
done
# 等待MONITOR_PUBLIC_IP设置
while [ -z "$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)" ];
do
  echo "wait set MONITOR_PUBLIC_IP, sleep 5s"
  # 等待5秒钟
  sleep 5
done
# 获取IP
MONITOR_PUBLIC_IP=$(cat /data/monitor_ip/MONITOR_PUBLIC_IP 2>/dev/null || true)
echo "MONITOR_PUBLIC_IP is $MONITOR_PUBLIC_IP"
# 生成配置文件
rm -rf /tmp/$channel_name.cfg
cp /home/template/neople/game/cfg/server.template /tmp/$channel_name.cfg
# 重设PUBLIC_IP,game密码,频道编号,端口信息等
sed -i "s/MAIN_BRIDGE_IP/$MAIN_BRIDGE_IP/g" /tmp/$channel_name.cfg
sed -i "s/CHANNEL_NO/$channel_no/g" /tmp/$channel_name.cfg
sed -i "s/PROCESS_SEQUENCE/$process_sequence/g" /tmp/$channel_name.cfg
sed -i "s/CORE_PUBLIC_IP/$CORE_PUBLIC_IP/g" /tmp/$channel_name.cfg
sed -i "s/P2P_PUBLIC_IP/$P2P_PUBLIC_IP/g" /tmp/$channel_name.cfg
sed -i "s/PUBLIC_IP/$MONITOR_PUBLIC_IP/g" /tmp/$channel_name.cfg
sed -i "s/DEC_GAME_PWD/$DEC_GAME_PWD/g" /tmp/$channel_name.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /tmp/$channel_name.cfg
cp /tmp/$channel_name.cfg /home/neople/game/cfg/$channel_name.cfg
echo "generate $channel_name.cfg success"
# 清理cfg文件
rm -rf /tmp/$channel_name.cfg
# 配置DB配置文件
rm -rf /home/neople/game/cfg/db_info_tw.cfg
cp /home/template/neople/game/cfg/db_info_tw.cfg /home/neople/game/cfg/db_info_tw.cfg
sed -i "s/SERVER_GROUP_NAME/$SERVER_GROUP_NAME/g" /home/neople/game/cfg/db_info_tw.cfg
sed -i "s/SERVER_GROUP/$SERVER_GROUP/g" /home/neople/game/cfg/db_info_tw.cfg
sed -i "s/CORE_PUBLIC_IP/$CORE_PUBLIC_IP/g" /home/neople/game/cfg/db_info_tw.cfg

# 启动服务
old_pid=$(pgrep -f "df_game_r $channel_name start")
echo "ch.$channel_no old pid is $old_pid"
if [ -n "$old_pid" ]; then
  echo "old pid not empty, kill $old_pid"
  kill -9 $old_pid
fi
rm -rf pid/$channel_name.pid

# patch geo allow[允许所有IP访问]
echo "🔍 正在查找 isAllow 函数地址..."
# 获取函数结束地址
END_ADDR=$(nm -S df_game_r | grep "_ZN19RestrictGeolocation7isAllowESsSs" | awk '{print $1, $2}')
if [ -z "$END_ADDR" ]; then
    echo "❌ 无法找到函数地址, 跳过geo allow patch"
else
    # ELF 基址（32位程序通常为 0x08048000）
    BASE_ADDR_HEX=0x08048000
    FUNC_SIZE=$(echo $END_ADDR | awk '{print $2}')
    START_ADDR=$(echo $END_ADDR | awk '{print $1}')
    # HEX地址
    START_ADDR_HEX=$(printf "0x%x" 0x$START_ADDR)
    END_ADDR_HEX=$(printf "0x%x" $((0x$START_ADDR + 0x$FUNC_SIZE)))
    # 计算文件偏移
    FILE_OFFSET=$((START_ADDR_HEX - BASE_ADDR_HEX))
    echo "✅ 找到函数地址: $START_ADDR_HEX - $END_ADDR_HEX"
    # patch 前查看函数反汇编
    objdump -d --start-address=$START_ADDR_HEX --stop-address=$END_ADDR_HEX df_game_r | head -30
    echo "🔧 开始 Patch 函数 (地址: $START_ADDR_HEX)..."
    
    # Patch 策略：把函数开头改为 mov eax,1; ret
    # 原指令: 55 89 e5 56 53 81 ec 90 00 00 00
    # 替换为: b8 01 00 00 00 c3 90 90 90 90 90
    perl -e '
        my $addr = hex($ARGV[0]);
        open my $f, "+<", "df_game_r" or die "打开文件失败: $!";
        seek $f, $addr, 0;
        print $f "\xB8\x01\x00\x00\x00\xC3";
        close $f;
        print "✅ Patch 完成\n";
    ' "$(printf '0x%x' $FILE_OFFSET)"
    if [ $? -eq 0 ]; then
        echo "✅ Patch 成功！函数已被强制返回 true"
        # 验证 patch 结果
        echo "📜 Patch 后反汇编:"
        sync
        objdump -d --start-address=$START_ADDR_HEX --stop-address=$END_ADDR_HEX df_game_r | head -30
    else
        echo "❌ Patch 失败"
    fi
fi

# 加载DP并启动[确保DP路径已经被正确映射]
LD_PRELOAD=/dp2/libhook.so ./df_game_r $channel_name start
sleep 5
pid=$(cat pid/$channel_name.pid 2>/dev/null || true)
cat pid/$channel_name.pid |xargs -n1 -I{} tail --pid={} -f /dev/null
echo "----------##############----------process exit, ch.$channel_no pid is $pid----------##############----------"
echo "----------##############----------启动失败,请检查PVF文件是否支持该大区----------##############----------"
echo "----------##############----------一般情况下100MB左右大小的PVF文件使用的是希洛克大区----------##############----------"
echo "----------##############----------可以尝试启动SERVER_GROUP=3----------##############----------"
# 只保留一个core文件
if [ -f "/home/neople/game/core.$pid" ];then
  rm -rf /data/core.latest
  mv /home/neople/game/core.$pid /data/core.latest
  # 删除CORE DUMP文件
  rm -rf /home/neople/game/core.*
fi

