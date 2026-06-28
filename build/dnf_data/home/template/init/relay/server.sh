#!/bin/bash

# 配置参数
PORT="500$SERVER_GROUP"
CONFIG_FILE="/data/relay/MONITOR_RELAY_CONFIG"

# 创建必要的目录
mkdir -p /data/relay

# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 处理注册请求
handle_registration() {
    local data="$1"
    
    # 解析数据: ip,relay_index,port
    local relay_ip=$(echo "$data" | cut -d',' -f1)
    local relay_index=$(echo "$data" | cut -d',' -f2)
    local relay_port=$(echo "$data" | cut -d',' -f3)
    
    # 验证数据完整性
    if [ -z "$relay_ip" ] || [ -z "$relay_index" ] || [ -z "$relay_port" ]; then
        log_info "ERROR: Invalid data format: $data"
        return 1
    fi
    
    log_info "Received: IP=$relay_ip, Index=$relay_index, Port=$relay_port"
    
    # 构建新配置行
    local new_line="Relay	1	0			${relay_index}	${relay_ip}		${relay_port}"
    
    # 更新配置文件
    update_config_file "$relay_ip" "$relay_index" "$relay_port" "$new_line"
}

# 更新配置文件
update_config_file() {
    local relay_ip="$1"
    local relay_index="$2"
    local relay_port="$3"
    local new_line="$4"
    
    local temp_file=$(mktemp)
    local found=0
    
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            if echo "$line" | grep -q "$relay_ip.*$relay_port" 2>/dev/null; then
                echo "$new_line" >> "$temp_file"
                found=1
                log_info "Exist: $relay_ip:$relay_port"
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$CONFIG_FILE"
    fi
    
    if [ $found -eq 0 ]; then
        echo "$new_line" >> "$temp_file"
        log_info "Added: $relay_ip:$relay_port"
    fi
    
    mv "$temp_file" "$CONFIG_FILE"
    if [ $found -eq 0 ]; then
        # 重启monitor服务
        cp /home/template/neople/monitor/cfg/server.cfg /home/neople/monitor/cfg/server.cfg
        # 将内容追加
        cat "$CONFIG_FILE" >> /home/neople/monitor/cfg/server.cfg
        log_info "Monitor config updated, restarting monitor service"
        # 打印配置内容
        cat /home/neople/monitor/cfg/server.cfg
        # 重启monitor服务
        supervisorctl restart core:monitor
    fi
}

# 主函数
main() {
    # 检查SERVER_TYPE
    if [ "$SERVER_TYPE" != "ALL" ] && [ "$SERVER_TYPE" != "CORE" ]; then
        log_info "SERVER_TYPE=$SERVER_TYPE, not ALL or CORE, exiting..."
        sleep 5
        exit 0
    fi
    
    log_info "Registration server started on port $PORT"
    log_info "SERVER_TYPE: $SERVER_TYPE"
    
    # 主循环
    while true; do
        # 使用nc接收数据
        data=$(nc -l -w 5 "$PORT" 2>/dev/null | head -n 1)
        
        if [ -n "$data" ]; then
            # 在子进程中处理，避免阻塞
            (
                handle_registration "$data"
            ) &
        fi
    done
}

# 运行主函数
main
