#!/bin/bash
# Debian 網絡配置腳本
# 功能：允許在固定IP（靜態）和浮動IP（DHCP）之間切換

# 檢查root權限
if [ "$EUID" -ne 0 ]; then
    echo "❌ 請使用 sudo 運行此腳本"
    exit 1
fi

# 自動檢測活動網卡
detect_interface() {
    # 優先選擇有默認網關的網卡
    DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}')
    
    # 如果沒有默認網關，選擇第一個有IPv4地址的非lo網卡
    if [ -z "$DEFAULT_IFACE" ]; then
        DEFAULT_IFACE=$(ip -o -4 addr show 2>/dev/null | awk '!/lo/ && /scope global/ {print $2; exit}')
    fi
    
    [ -n "$DEFAULT_IFACE" ] && echo "$DEFAULT_IFACE" || echo ""
}

# 驗證IP/CIDR格式
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

# 驗證IP格式
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

# 獲取當前IP
get_current_ip() {
    local iface=$1
    ip -4 addr show dev $iface 2>/dev/null | awk '/inet/ && !/secondary/ {print $2}' | head -n1
}

# 獲取當前網關
get_current_gateway() {
    ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1
}

# 獲取當前網絡模式
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

# 應用網絡配置
apply_network_config() {
    local iface=$1
    local mode=$2
    local ip_cidr=$3
    local gateway=$4
    
    # 備份原始配置文件
    BACKUP_FILE="/etc/network/interfaces.$(date +%Y%m%d-%H%M%S).bak"
    cp /etc/network/interfaces "$BACKUP_FILE"
    echo "✅ 配置文件已備份至: $BACKUP_FILE"
    
    # 創建臨時配置文件
    TEMP_FILE=$(mktemp)
    cat /etc/network/interfaces > $TEMP_FILE
    
    # 删除所有與當前網卡相關的配置
    sed -i "/auto $iface/,/^\s*$/d" $TEMP_FILE
    
    # 添加新配置
    if [ "$mode" == "static" ]; then
        cat >> $TEMP_FILE <<EOF

# 靜態IP配置 (由腳本生成於 $(date))
auto $iface
iface $iface inet static
    address $ip_cidr
    gateway $gateway
EOF
    else
        cat >> $TEMP_FILE <<EOF

# DHCP配置 (由腳本生成於 $(date))
auto $iface
iface $iface inet dhcp
EOF
    fi
    
    # 應用新配置
    mv $TEMP_FILE /etc/network/interfaces
    
    echo "🔄 配置已更新:"
    echo "----------------------------------------"
    grep -A 3 "iface $iface" /etc/network/interfaces
    echo "----------------------------------------"
    
    # 應用網絡配置
    echo "🔄 正在應用網絡配置..."
    echo "步驟1: 清除現有IP地址..."
    ip addr flush dev $iface 2>/dev/null
    
    echo "步驟2: 關閉網卡..."
    ifdown $iface --force 2>/dev/null
    
    echo "步驟3: 啟動網卡..."
    if ! ifup $iface; then
        echo "⚠️ ifup 失敗，嘗試替代方法..."
        
        if [ "$mode" == "static" ]; then
            # 嘗試手動設置靜態IP
            IP_ADDR=$(echo $ip_cidr | cut -d'/' -f1)
            PREFIX=$(echo $ip_cidr | cut -d'/' -f2)
            
            echo "手動設置IP: $IP_ADDR/$PREFIX"
            ip addr add $IP_ADDR/$PREFIX dev $iface
            
            echo "手動設置網關: $gateway"
            ip route add default via $gateway dev $iface
        else
            # 嘗試手動獲取DHCP
            echo "手動獲取DHCP地址..."
            dhclient -r $iface
            dhclient $iface
        fi
    fi
}

# 主程序
INTERFACE=$(detect_interface)

if [ -z "$INTERFACE" ]; then
    echo "❌ 錯誤：未檢測到活動網卡"
    exit 1
fi

echo "🔍 檢測到活動網卡: $INTERFACE"

# 獲取當前網絡配置
CURRENT_IP=$(get_current_ip $INTERFACE)
CURRENT_GW=$(get_current_gateway)
CURRENT_MODE=$(get_current_mode $INTERFACE)

# 顯示當前網絡配置
echo ""
echo "📝 當前網絡配置:"
echo "----------------------------------------"
if [ -n "$CURRENT_IP" ]; then
    echo "當前IP:   $CURRENT_IP"
else
    echo "當前IP:   未檢測到"
fi

if [ -n "$CURRENT_GW" ]; then
    echo "當前網關: $CURRENT_GW"
else
    echo "當前網關: 未檢測到"
fi

echo "當前模式: ${CURRENT_MODE^^}"
echo "----------------------------------------"

# 選擇配置模式
echo ""
echo "📌 請選擇網絡配置模式:"
echo "1) 固定IP (靜態)"
echo "2) 浮動IP (DHCP)"
echo "----------------------------------------"

while true; do
    read -p "請輸入選項 (1/2): " choice
    case $choice in
        1)
            MODE="static"
            echo "您選擇了: 固定IP (靜態)"
            break
            ;;
        2)
            MODE="dhcp"
            echo "您選擇了: 浮動IP (DHCP)"
            break
            ;;
        *)
            echo "❌ 無效選項，請重新輸入"
            ;;
    esac
done

# 如果是靜態模式，獲取IP和網關
if [ "$MODE" == "static" ]; then
    echo ""
    echo "📌 請輸入靜態IP配置"
    echo "----------------------------------------"
    
    while true; do
        read -p "請輸入IP地址/CIDR (例如: 192.168.1.100/24): " IP_CIDR
        if validate_ip_cidr "$IP_CIDR"; then
            break
        else
            echo "❌ 無效的IP/CIDR格式，請重新輸入"
        fi
    done
    
    while true; do
        read -p "請輸入網關地址: " GATEWAY
        if validate_ip "$GATEWAY"; then
            break
        else
            echo "❌ 無效的網關地址，請重新輸入"
        fi
    done
    
    echo "----------------------------------------"
    echo "✅ 配置確認:"
    echo "網卡:    $INTERFACE"
    echo "模式:    靜態"
    echo "IP/CIDR: $IP_CIDR"
    echo "網關:    $GATEWAY"
else
    echo ""
    echo "✅ 配置確認:"
    echo "網卡:    $INTERFACE"
    echo "模式:    DHCP"
fi

echo "----------------------------------------"

read -p "是否應用此配置? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 應用配置
if [ "$MODE" == "static" ]; then
    apply_network_config $INTERFACE $MODE $IP_CIDR $GATEWAY
else
    apply_network_config $INTERFACE $MODE
fi

# 獲取新網絡配置
NEW_IP=$(get_current_ip $INTERFACE)
NEW_GW=$(get_current_gateway)
NEW_MODE=$(get_current_mode $INTERFACE)

# 驗證配置
echo ""
echo "🔍 驗證新配置:"
echo "----------------------------------------"
if [ "$MODE" == "static" ]; then
    echo "配置IP:   $IP_CIDR"
    echo "當前IP:   ${NEW_IP:-未檢測到}"
    echo ""
    echo "配置網關: $GATEWAY"
    echo "當前網關: ${NEW_GW:-未檢測到}"
else
    echo "當前IP:   ${NEW_IP:-未檢測到}"
    echo "當前網關: ${NEW_GW:-未檢測到}"
fi
echo ""
echo "配置模式: ${MODE^^}"
echo "當前模式: ${NEW_MODE^^}"
echo ""

# 測試網絡連通性
TEST_HOST="8.8.8.8"
if [ -n "$NEW_GW" ]; then
    echo "測試網關連通性:"
    if ping -c 2 -W 1 $NEW_GW >/dev/null 2>&1; then
        echo "✅ 網關 $NEW_GW 可達"
        
        echo "測試互聯網連通性:"
        if ping -c 2 -W 1 $TEST_HOST >/dev/null 2>&1; then
            echo "✅ 互聯網連接正常 ($TEST_HOST 可達)"
        else
            echo "⚠️ 警告: 無法訪問互聯網 ($TEST_HOST 不可達)"
        fi
    else
        echo "⚠️ 警告: 網關 $NEW_GW 不可達"
    fi
else
    echo "⚠️ 警告: 未檢測到默認網關"
fi
echo "----------------------------------------"

echo ""
echo "✅ 網絡配置完成!"
echo "📌 如需恢複原配置: sudo cp $BACKUP_FILE /etc/network/interfaces && sudo systemctl restart networking"