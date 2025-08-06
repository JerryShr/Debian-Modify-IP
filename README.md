# Debian 网络配置脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12-blue?logo=debian)](https://www.debian.org/)

这是一个用于在 Debian 系统上轻松切换网络配置的脚本工具，支持在固定IP（静态）和浮动IP（DHCP）之间切换。

## 功能特点

- 🖥️ 自动检测活动网卡
- ⚙️ 支持静态IP和DHCP两种模式
- 🌐 多语言支持（简体中文、繁体中文、美式英语）
- 🔍 配置前后验证和网络连通性测试
- 🔄 自动备份和恢复机制
- ✅ 输入格式验证和错误处理

## 使用说明

### 前提条件
- Debian 10/11/12 系统
- 需要 root 权限执行
- 使用传统 networking 服务（非 NetworkManager）

### 使用方法

1. 下载脚本：
   ```bash
   curl -fsSL https://github.com/JerryShr/Debian-Modify-IP/blob/main/Modify-IP_CN.sh
   sh Modify-IP_CN.sh
根据您的语言偏好选择脚本：

简体中文：Modify-IP_CN.sh

繁体中文：Modify-IP_TW.sh

美式英语：Modify-IP_US.sh

赋予执行权限：

bash
chmod +x Modify-IP_*.sh
运行脚本：

bash
sudo ./Modify-IP_CN.sh   # 使用简体中文版
按照提示操作：

查看当前网络配置

选择配置模式（固定IP或浮动IP）

输入网络参数（如选择固定IP模式）

确认并应用配置

脚本选择指南
脚本名称	语言	适用系统区域
Modify-IP_CN.sh	简体中文	中国大陆、新加坡等
Modify-IP_TW.sh	繁体中文	台湾、香港、澳门等
Modify-IP_US.sh	美式英语	美国及其他英语国家
恢复配置
如果遇到问题，脚本会自动创建备份文件，您可以使用以下命令恢复原始配置：

bash
sudo cp /etc/network/interfaces.<timestamp>.bak /etc/network/interfaces
sudo systemctl restart networking
