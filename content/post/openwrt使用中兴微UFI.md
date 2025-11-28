---
date: 2025-11-28 11:37:40
lastmod: 2025-11-28 11:37:40
title: "小米 Mini 刷 OpenWrt 24.10 使用品胜 MA156 (中兴微) 4G 网卡"
author: "k"
# weight: 1
# aliases: ["/first"]
tags: ["openwrt"]
categories: []
draft: false
comments: true
description: "小米 Mini 刷 OpenWrt 24.10 使用品胜 MA156 (中兴微) 4G 网卡"
---


<!-- # 小米 Mini 刷 OpenWrt 24.10 使用品胜 MA156 (中兴微) 4G 网卡 -->
## 小米 Mini 刷 OpenWrt 24.10 使用品胜 MA156 (中兴微) 4G 网卡

手头有一台吃灰多年的**小米路由器 Mini**，想着把它利用起来做一个 4G 上网热点。经历了一番折腾，从刷机到驱动网卡，特别是解决\*\*品胜 MA156（中兴微芯片）\*\*被识别成 U 盘的问题，积累了一些经验。

本文记录了我完整的排查和解决过程，希望能帮到同样遇到“插上 4G 棒子没反应”的朋友。

## 1. 环境准备

首先把小米 Mini 刷成了最新的 **OpenWrt 24.10.0** 版本。

* **设备**：小米路由器 Mini (MT7620)
* **系统**：OpenWrt 24.10.0 (Linux 6.6.73)

## 2. 安装 USB 基础驱动包

刷完机第一件事，就是安装 USB 支持包。因为不知道网卡具体用什么协议，所以我把常见的 USB 网络驱动都装上了，确保万无一失。

SSH 登录路由器，执行安装：

```bash
opkg update
opkg list | grep usb  # 查看当前包（这是我安装好的列表）
```

**核心安装包清单：**

* `kmod-usb-core`, `kmod-usb2` (基础 USB 支持)
* `usb-modeswitch` (关键！用于模式切换)
* `kmod-usb-net`, `kmod-usb-net-cdc-ether`, `kmod-usb-net-rndis` (网卡协议驱动)

## 3. 测试：中兴网卡 (正常)

为了确认路由器的 USB 口和基础驱动没问题，我先插了一个老款的**中兴 USB 上网卡**。

* **结果**：插上后，系统日志直接识别出 LTE 设备，在“网络 -> 接口”里直接能看到 `usb0` 网卡。
* **结论**：说明 OpenWrt 24.10 的 USB 功能和基础驱动是正常的。

## 4. 问题出现：品胜 MA156 (中兴微) 罢工

拔掉华为，插上这次的主角——**品胜 MA156**（拆机确认是中兴微 ZXIC 方案）。

* **现象**：路由器没有任何反应，在网络接口里找不到新网卡。
* **初步判断**：驱动没挂载上，或者设备模式不对。

## 5. 深入排查：寻找“失踪”的网卡

为了搞清楚发生了什么，我在终端输入了查看 USB 状态的命令：

```bash
cat /sys/kernel/debug/usb/devices
```

**获取到的关键信息（节选）：**

```text
T:  Bus=01 Lev=01 ... Dev#=  3 Spd=480  MxCh= 0
P:  Vendor=19d2 ProdID=0557 Rev= 1.01
S:  Manufacturer=ALK,Incorporated
S:  Product=ALK Mobile Boardband
C:* #Ifs= 1 Cfg#= 1 Atr=c0 MxPwr=500mA
I:* If#= 0 Alt= 0 #EPs= 2 Cls=08(stor.) Sub=06 Prot=50 Driver=(none)
```

**🔴 问题找到了：**

1. **ID**：`19d2:0557`。
2. **Cls=08(stor.)**：这是最明显的证据。`08` 代表 **Mass Storage**，也就是说 OpenWrt 把它当成了一个 **U 盘/光驱**。
3. **Driver=(none)**：因为是 U 盘模式，但又没挂载存储驱动，所以这里是空的。

这就是所谓的 **ZeroCD 模式**：网卡为了兼容 Windows 驱动安装，默认伪装成光驱。我们需要做的是让它“变身”。

## 6. 解决：修改 `usb-mode.json`

既然知道它是中兴微的芯片，且处于存储模式，就需要配置 `usb-modeswitch` 来触发它切换。

OpenWrt 24.10 使用 `/etc/usb-mode.json` 来管理设备库。我查阅资料后发现，中兴微的设备通常支持 **`StandardEject`**（标准弹出）模式——只要模拟弹出光驱，它就会自动切换成网卡。

**操作步骤：**
编辑配置文件 `vi /etc/usb-mode.json`，加入了以下针对 `19d2:0557` 的配置：

```json
"19d2:0557": {
    "*": {
        "mode": "StandardEject",
        "msg": [ ]
    }
}
```

(注意：这里利用了 OpenWrt 自带的 StandardEject 机制，比填一大串 16 进制代码更稳)

## 7. 修改前后的对比

修改保存后，我拔掉网卡重新插入，让 `usbmode` 重新扫描。

再次运行 `lsusb -v` 和 `cat /sys/kernel/debug/usb/devices`，我们可以看到明显的**差异对比**：

| 对比项 | 修改前 (未识别) 🔴 | 修改后 (成功识别) 🟢 |
| :--- | :--- | :--- |
| **设备 ID** | `19d2:0557` | **`19d2:0558`** (ID 变了！) |
| **设备类型** | `Cls=08(stor.)` (U 盘) | **`Cls=02(comm.)`** (通信设备) |
| **识别描述** | Mass Storage | **CDC Ethernet Control Model (ECM)** |
| **驱动程序** | `Driver=(none)` | **`Driver=cdc_ether`** |
| **网络接口** | 无 | 出现 **`eth1`** |

**系统日志证实了切换成功：**

```text
Bus 001 Device 003: ID 19d2:0558 ALK,Incorporated ALK Mobile Boardband
bInterfaceClass      2 [unknown]
iInterface           6 CDC Ethernet Control Model (ECM)
```

系统识别出了 CDC Ethernet 协议，并加载了对应的驱动。

## 8. 最后一步：Web 端添加接口

既然底层已经认出了 `eth1`，剩下的就在 LuCI 网页端点点鼠标了。

1. 登录 OpenWrt 后台，进入 **网络 -\> 接口**。
2. 点击 **添加新接口**。
3. **名称**：随便填，比如 `LTE`。
4. **协议**：选 **DHCP 客户端**（因为 UFI 棒子自带路由功能）。
5. **设备**：在下拉列表中选择 **Ethernet Adapter: "eth1"** (也就是刚才识别出来的 usb0)。
6. 保存并应用。

稍等几秒，可以看到 IP 地址已经获取到了，网络连接成功！
