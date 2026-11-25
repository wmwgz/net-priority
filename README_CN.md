# NetPriority（macOS 网卡优先级管理）

[English](README.md) | 简体中文

原生轻量 macOS（SwiftUI + AppKit）工具，用于在 **Wi-Fi 与多款不同有线 / USB 网卡**之间一键切换默认上网优先级，支持一键把指定网卡设为「**仅内网管理（无网关）**」，并在顶部菜单栏实时显示当前默认出口。

## 核心亮点

- **精准区分多款有线/USB 设备**：同时插着扩展坞千兆网卡、随身 WiFi USB 口、手机 USB 共享时，不再只能“Wi-Fi / 有线二选一”，可直接挑中任意设备设为 `#1`。
- **一键「仅内网管理 / 允许上网」**：给需要调管理后台的网卡（有线或 Wi-Fi 均可）一键配成手动 IP、**不填默认网关并关闭 IPv6**（例如访问 `192.168.0.1` 管理页的同时完全不抢默认网）；点「允许上网」即可秒回 DHCP 自动模式。
- **自动过滤串口与虚拟扩展**：默认隐藏 `J-Link`、`USB JTAG` 调试串口以及无设备节点的 VPN 虚拟项（需要时可随时勾选展开），拖拽重排顺位时自动完整保留隐藏项顺位不丢失。
- **独立主窗口 + 菜单栏常驻**：通过 `SCDynamicStore` 实时监听热插拔与默认路由变化，关闭主窗口后自动驻留顶部菜单栏，点击即可秒切出口。
- **多语言实时切换**：支持 **跟随系统 / 简体中文 / English / 日本語**，窗口工具栏和顶部菜单栏均支持免重启即时切换。

## 主要功能

- 顶部卡片实时显示当前默认上网出口、IPv4、默认网关、IPv6 与链路速率
- 一键 `优先 Wi-Fi`、`优先有线`（分体下拉可指定具体有线设备）
- 列表拖拽排序 + `↑ / ↓` 微调 + 单网卡启用/禁用开关
- 单网卡 `仅内网` / `允许上网`（支持右键自定义静态内网 IP 与掩码）
- 自定义设备中文备注别名（如将随身 WiFi 序列号备注为「随身WiFi」）
- 单实例防多开保护、标准 macOS 快捷键与 `LaunchAgent` 开机静默自启

## 环境要求

- macOS 14.0+
- Swift 5.9+（Xcode 或 Command Line Tools 均可）

## 编译与安装

```bash
git clone https://github.com/<your-username>/net-priority.git
cd net-priority
swift run NetPrioritySelfTest
./scripts/build_app.sh
```

脚本会自动运行全部单元测试、编译 Release 版本、生成图标、签名并安装到 `/Applications/NetPriority.app`。

### 首次打开提示说明（未公证版本）

如果从 Release 下载未经过 Apple 开发者公证的压缩包时被系统拦截，可先执行以下命令移除隔离属性后再打开：

```bash
xattr -cr /Applications/NetPriority.app
```

## 开源协议

基于 [MIT](LICENSE) 协议开源。
