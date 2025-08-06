#!/bin/bash
# Debian 网络配置脚本
# 功能：允许在固定IP（静态）和浮动IP（DHCP）之间切换

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 自动检测活动网卡
detect_interface() {
    # 优先选择有默认网关的网卡
    DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}')
    
    # 如果没有默认网关，选择第一个有IPv4地址的非lo网卡
    if [ -z "$DEFAULT_IFACE" ]; then
        DEFAULT_IFACE=$(ip -o -4 addr show 2>/dev/null | awk '!/lo/ && /scope global/ {print $2; exit}')
    fi
    
    [ -n "$DEFAULT_IFACE" ] && echo "$DEFAULT_IFACE" || echo ""
}

# 验证IP/CIDR格式
validate_ip_cidr() {
    local ip_cidr=$1
    if [[ $ip_cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        IFS='/' read -r ip cidr <<< "$ip_cidr"
        IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
        if [ "$i1" -le 255 ] && [ "$i2" -le 255 ] && [ "$i3" -le 255 ] && [ "$i4" -le 255 ] && [ "$cidr" -le 32 ]; then
            return 0
        fi
    fi
    return 1
}

# 验证IP格式
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
        if [ "$i1" -le 255 ] && [ "$i2" -le 255 ] && [ "$i3" -le 255 ] && [ "$i4" -le 255 ]; then
            return 0
        fi
    fi
    return 1
}

# 获取当前IP
get_current_ip() {
    local iface=$1
    ip -4 addr show dev $iface 2>/dev/null | awk '/inet/ && !/secondary/ {print $2}' | head -n1
}

# 获取当前网关
get_current_gateway() {
    ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1
}

# 获取当前网络模式
get_current_mode() {
    local iface=$1
    if grep -q "iface $iface inet dhcp" /etc/network/interfaces; then
        echo "dhcp"
    elif grep -q "iface $iface inet static" /etc/network/interfaces; then
        echo "static"
    else
        echo "unknown"
    fi
}

# 应用网络配置
apply_network_config() {
    local iface=$1
    local mode=$2
    local ip_cidr=$3
    local gateway=$4
    
    # 备份原始配置文件
    BACKUP_FILE="/etc/network/interfaces.$(date +%Y%m%d-%H%M%S).bak"
    cp /etc/network/interfaces "$BACKUP_FILE"
    echo "✅ 配置文件已备份至: $BACKUP_FILE"
    
    # 创建临时配置文件
    TEMP_FILE=$(mktemp)
    cat /etc/network/interfaces > $TEMP_FILE
    
    # 删除所有与当前网卡相关的配置
    sed -i "/auto $iface/,/^\s*$/d" $TEMP_FILE
    
    # 添加新配置
    if [ "$mode" == "static" ]; then
        cat >> $TEMP_FILE <<EOF

# 静态IP配置 (由脚本生成于 $(date))
auto $iface
iface $iface inet static
    address $ip_cidr
    gateway $gateway
EOF
    else
        cat >> $TEMP_FILE <<EOF

# DHCP配置 (由脚本生成于 $(date))
auto $iface
iface $iface inet dhcp
EOF
    fi
    
    # 应用新配置
    mv $TEMP_FILE /etc/network/interfaces
    
    echo "🔄 配置已更新:"
    echo "----------------------------------------"
    grep -A 3 "iface $iface" /etc/network/interfaces
    echo "----------------------------------------"
    
    # 应用网络配置
    echo "🔄 正在应用网络配置..."
    echo "步骤1: 清除现有IP地址..."
    ip addr flush dev $iface 2>/dev/null
    
    echo "步骤2: 关闭网卡..."
    ifdown $iface --force 2>/dev/null
    
    echo "步骤3: 启动网卡..."
    if ! ifup $iface; then
        echo "⚠️ ifup 失败，尝试替代方法..."
        
        if [ "$mode" == "static" ]; then
            # 尝试手动设置静态IP
            IP_ADDR=$(echo $ip_cidr | cut -d'/' -f1)
            PREFIX=$(echo $ip_cidr | cut -d'/' -f2)
            
            echo "手动设置IP: $IP_ADDR/$PREFIX"
            ip addr add $IP_ADDR/$PREFIX dev $iface
            
            echo "手动设置网关: $gateway"
            ip route add default via $gateway dev $iface
        else
            # 尝试手动获取DHCP
            echo "手动获取DHCP地址..."
            dhclient -r $iface
            dhclient $iface
        fi
    fi
}

# 主程序
INTERFACE=$(detect_interface)

if [ -z "$INTERFACE" ]; then
    echo "❌ 错误：未检测到活动网卡"
    exit 1
fi

echo "🔍 检测到活动网卡: $INTERFACE"

# 获取当前网络配置
CURRENT_IP=$(get_current_ip $INTERFACE)
CURRENT_GW=$(get_current_gateway)
CURRENT_MODE=$(get_current_mode $INTERFACE)

# 显示当前网络配置
echo ""
echo "📝 当前网络配置:"
echo "----------------------------------------"
if [ -n "$CURRENT_IP" ]; then
    echo "当前IP:   $CURRENT_IP"
else
    echo "当前IP:   未检测到"
fi

if [ -n "$CURRENT_GW" ]; then
    echo "当前网关: $CURRENT_GW"
else
    echo "当前网关: 未检测到"
fi

echo "当前模式: ${CURRENT_MODE^^}"
echo "----------------------------------------"

# 选择配置模式
echo ""
echo "📌 请选择网络配置模式:"
echo "1) 固定IP (静态)"
echo "2) 浮动IP (DHCP)"
echo "----------------------------------------"

while true; do
    read -p "请输入选项 (1/2): " choice
    case $choice in
        1)
            MODE="static"
            echo "您选择了: 固定IP (静态)"
            break
            ;;
        2)
            MODE="dhcp"
            echo "您选择了: 浮动IP (DHCP)"
            break
            ;;
        *)
            echo "❌ 无效选项，请重新输入"
            ;;
    esac
done

# 如果是静态模式，获取IP和网关
if [ "$MODE" == "static" ]; then
    echo ""
    echo "📌 请输入静态IP配置"
    echo "----------------------------------------"
    
    while true; do
        read -p "请输入IP地址/CIDR (例如: 192.168.1.100/24): " IP_CIDR
        if validate_ip_cidr "$IP_CIDR"; then
            break
        else
            echo "❌ 无效的IP/CIDR格式，请重新输入"
        fi
    done
    
    while true; do
        read -p "请输入网关地址: " GATEWAY
        if validate_ip "$GATEWAY"; then
            break
        else
            echo "❌ 无效的网关地址，请重新输入"
        fi
    done
    
    echo "----------------------------------------"
    echo "✅ 配置确认:"
    echo "网卡:    $INTERFACE"
    echo "模式:    静态"
    echo "IP/CIDR: $IP_CIDR"
    echo "网关:    $GATEWAY"
else
    echo ""
    echo "✅ 配置确认:"
    echo "网卡:    $INTERFACE"
    echo "模式:    DHCP"
fi

echo "----------------------------------------"

read -p "是否应用此配置? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 应用配置
if [ "$MODE" == "static" ]; then
    apply_network_config $INTERFACE $MODE $IP_CIDR $GATEWAY
else
    apply_network_config $INTERFACE $MODE
fi

# 获取新网络配置
NEW_IP=$(get_current_ip $INTERFACE)
NEW_GW=$(get_current_gateway)
NEW_MODE=$(get_current_mode $INTERFACE)

# 验证配置
echo ""
echo "🔍 验证新配置:"
echo "----------------------------------------"
if [ "$MODE" == "static" ]; then
    echo "配置IP:   $IP_CIDR"
    echo "当前IP:   ${NEW_IP:-未检测到}"
    echo ""
    echo "配置网关: $GATEWAY"
    echo "当前网关: ${NEW_GW:-未检测到}"
else
    echo "当前IP:   ${NEW_IP:-未检测到}"
    echo "当前网关: ${NEW_GW:-未检测到}"
fi
echo ""
echo "配置模式: ${MODE^^}"
echo "当前模式: ${NEW_MODE^^}"
echo ""

# 测试网络连通性
TEST_HOST="8.8.8.8"
if [ -n "$NEW_GW" ]; then
    echo "测试网关连通性:"
    if ping -c 2 -W 1 $NEW_GW >/dev/null 2>&1; then
        echo "✅ 网关 $NEW_GW 可达"
        
        echo "测试互联网连通性:"
        if ping -c 2 -W 1 $TEST_HOST >/dev/null 2>&1; then
            echo "✅ 互联网连接正常 ($TEST_HOST 可达)"
        else
            echo "⚠️ 警告: 无法访问互联网 ($TEST_HOST 不可达)"
        fi
    else
        echo "⚠️ 警告: 网关 $NEW_GW 不可达"
    fi
else
    echo "⚠️ 警告: 未检测到默认网关"
fi
echo "----------------------------------------"

echo ""
echo "✅ 网络配置完成!"
echo "📌 如需恢复原配置: sudo cp $BACKUP_FILE /etc/network/interfaces && sudo systemctl restart networking"