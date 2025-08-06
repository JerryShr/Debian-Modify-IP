# Debian 網路IP設定腳本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12-blue?logo=debian)](https://www.debian.org/)

這是一個用於在 Debian 系統上輕鬆切換網路配置的腳本工具，支援在固定IP（靜態）和浮動IP（DHCP）之間切換。

## 功能特點

- 🖥️ 自動偵測活動網路卡
- ⚙️ 支援靜態IP和DHCP兩種模式
- 🌐 多語言支援（簡體中文、繁體中文、美式英文）
- 🔍 配置前後驗證和網路連通性測試
- 🔄 自動備份與復原機制
- ✅ 輸入格式驗證與錯誤處理

## 使用說明

### 前提條件
- Debian 10/11/12 系統
- 需要 root 權限執行
- 使用傳統 networking 服務（非 NetworkManager）

### 使用方法

1-1. 簡體中文：Modify-IP_CN.sh 下载脚本：
   ```bash
   curl -fsSL https://github.com/JerryShr/Debian-Modify-IP/blob/main/Modify-IP_CN.sh
   chmod +x Modify-IP_CN.sh
   sudo ./Modify-IP_CN.sh```
   
1-2. 繁体中文：Modify-IP_CN.sh 下载脚本：
   ```bash
   curl -fsSL https://github.com/JerryShr/Debian-Modify-IP/blob/main/Modify-IP_TW.sh
   chmod +x Modify-IP_TW.sh
   sudo ./Modify-IP_TW.sh```
   
1-3. 美式英語：Modify-IP_CN.sh 下载脚本：
   ```bash
   curl -fsSL https://github.com/JerryShr/Debian-Modify-IP/blob/main/Modify-IP_US.sh
   chmod +x Modify-IP_US.sh
   sudo ./Modify-IP_US.sh```

### 依照提示操作：

查看目前網路配置

選擇配置模式（固定IP或浮動IP）

輸入網路參數（如選擇固定IP模式）

確認並套用配置

### 腳本選擇指南
腳本名稱 語言 適用系統區域
Modify-IP_CN.sh 簡體中文 中國大陸、新加坡等
Modify-IP_TW.sh 繁體中文 台灣、香港、澳門等
Modify-IP_US.sh 美式英語 美國及其他英語國家

### 恢復配置
如果遇到問題，腳本會自動建立備份文件，您可以使用以下命令恢復原始配置：

bash
sudo cp /etc/network/interfaces.<timestamp>.bak /etc/network/interfaces
sudo systemctl restart networking
