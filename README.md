# OpenClawTrader（⚠️ 已废弃）

> ⚠️ **状态：本项目已废弃。请勿继续开发。**
> 
> 妙股AI的正确项目是 `/Users/zifanni/openclaw/MiaoguAI/`
> 路径确认（2026-04-07）：`~/openclaw/MiaoguAI/docs/DEVELOPMENT.md`

---

> **历史说明（旧）**
> iOS App + Cloud Relay Server，实现移动端与 OpenClaw 桌面端的配对连接与消息中继。

[![GitHub Repo](https://img.shields.io/badge/GitHub-Cyril0404%2FOpenClawTrader-blue)](https://github.com/Cyril0404/OpenClawTrader)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D18-green)](https://nodejs.org/)
[![iOS](https://img.shields.io/badge/iOS-17%2B-000000)](https://developer.apple.com/documentation/xcode)

---

## 项目简介

OpenClawTrader 是一款 iOS 应用，通过云端 WebSocket 中继服务连接 OpenClaw 桌面端 Gateway，实现：

- 📱 **移动端配对**：扫码或手动输入配对码连接桌面端
- 🔄 **消息中继**：iOS 与桌面端之间的实时消息传递
- 🤖 **AI 对话**：通过 OpenClaw 桌面端调用本地 AI 进行对话

---

## 技术架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      OpenClawTrader 系统                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────────┐      ┌──────────────────┐      ┌──────────┐│
│   │              │      │                  │      │          ││
│   │   iOS App    │◄────►│  Cloud Relay     │◄────►│ Desktop  ││
│   │  (妙股 App)  │      │  Server (腾讯云)  │      │ Gateway  ││
│   │              │      │  ws://150.158    │      │          ││
│   │  配对 + 收发  │      │  .119.114:3001   │      │ ClawRed  ││
│   └──────────────┘      └──────────────────┘      └──────────┘│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**技术栈**：
| 组件 | 技术 |
|------|------|
| iOS App | SwiftUI + UIKit (AVFoundation) |
| Cloud Relay | Node.js + Express + ws |
| Desktop Gateway | Node.js (OpenClaw) |
| 进程管理 | PM2 |

---

## 目录结构

```
OpenClawTrader/
├── iOS/                          # iOS App 源代码
│   ├── OpenClawTrader.xcodeproj/ # Xcode 项目
│   ├── App/                      # App 入口
│   ├── Features/Profile/         # 配对页面
│   └── Services/PairingService.swift  # 配对服务
│
├── relay-server/                 # 云端中继服务
│   ├── src/
│   │   ├── index.js              # 主入口
│   │   ├── api/pair.js          # 配对 API
│   │   ├── relay/                # 连接管理
│   │   └── relay-client/        # 桌面端客户端
│   ├── data/                     # 持久化数据
│   └── pm2.config.js             # PM2 配置
│
├── docs/                         # 文档
│   ├── ARCHITECTURE.md           # 系统架构
│   ├── PAIRING_TROUBLESHOOTING.md  # 配对问题排查
│   ├── PROBLEM_LOG.md            # 问题解决记录
│   └── RELAY_SERVER.md           # relay-server 部署
│
├── CLAWRED_SETUP.md              # ClawRed 桌面端指南
├── DEVELOPMENT.md                # 开发手册
└── CHANGELOG.md                  # 变更日志
```

---

## 快速开始

### iOS App

```bash
cd iOS/OpenClawTrader.xcodeproj
# 用 Xcode 打开并运行
open OpenClawTrader.xcodeproj
```

### relay-server

```bash
cd relay-server

# 安装依赖
npm install

# 开发环境
npm run dev

# 生产环境（PM2）
pm2 start pm2.config.js
```

### ClawRed 桌面端

```bash
cd relay-server

# 生成配对码
npm run pair

# 或连接到 relay
npm run connect
```

---

## 配对流程

1. **桌面端**：运行 `npm run pair`，终端显示二维码
2. **iOS**：打开 App → 扫码 → 输入/扫描配对码
3. **验证**：App 调用 `/api/pair/verify` 验证配对码
4. **连接**：验证成功后 WebSocket 连接到 relay server
5. **完成**：双向消息通道建立

详细流程见 [ARCHITECTURE.md](./docs/ARCHITECTURE.md)。

---

## 相关文档

| 文档 | 说明 |
|------|------|
| [DEVELOPMENT.md](./DEVELOPMENT.md) | 开发手册 |
| [ARCHITECTURE.md](./docs/ARCHITECTURE.md) | 系统架构详解 |
| [PAIRING_TROUBLESHOOTING.md](./docs/PAIRING_TROUBLESHOOTING.md) | 配对问题排查 |
| [PROBLEM_LOG.md](./docs/PROBLEM_LOG.md) | 问题解决记录（2026-03-29） |
| [RELAY_SERVER.md](./docs/RELAY_SERVER.md) | relay-server 腾讯云部署 |
| [CLAWRED_SETUP.md](./CLAWRED_SETUP.md) | ClawRed 桌面端使用 |

---

## 云端服务

| 环境 | 地址 |
|------|------|
| **生产 relay** | `ws://150.158.119.114:3001` |
| **API** | `http://150.158.119.114:3001/api` |

---

## GitHub

- **iOS App**: https://github.com/Cyril0404/OpenClawTrader
- **relay-server**: 已集成到本仓库 `relay-server/` 目录

---

*最后更新: 2026-03-29*
