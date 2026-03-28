# OpenClaw Trader - 开发手册 v1.0

## 目录
1. [项目概述](#1-项目概述)
2. [技术架构](#2-技术架构)
3. [开发环境](#3-开发环境)
4. [云端中继服务](#4-云端中继服务)
5. [移动端配对流程](#5-移动端配对流程)
6. [核心模块说明](#6-核心模块说明)
7. [构建与部署](#7-构建与部署)

---

## 1. 项目概述

OpenClaw Trader 是一款 iOS 应用，用于与 OpenClaw 桌面端 Gateway 进行配对连接，实现移动端与桌面端的消息中继。

### 1.1 核心功能
- **移动端配对**：通过扫码或手动输入配对码连接桌面端
- **消息中继**：移动端通过云端 WebSocket 中继与桌面端通信
- **AI 对话**：将用户消息转发至本地 AI 进行处理

### 1.2 技术栈
| 组件 | 技术 |
|------|------|
| iOS App | SwiftUI + UIKit (AVFoundation) |
| 桌面端 Gateway | Node.js + WebSocket |
| 云端中继服务 | Node.js + Express + ws |
| 网络协议 | HTTPS + WebSocket |

---

## 2. 技术架构

### 2.1 系统架构图

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│   iOS App       │     │  Cloud Relay    │     │  Desktop        │
│   (移动端)      │◄───►│  Server         │◄───►│  Gateway        │
│                 │     │  (云端中继)      │     │  (桌面端)        │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       │                        │                        │
       │   QR Code / 配对码      │    WebSocket           │
       │ ─────────────────────► │ ─────────────────────► │
       │                        │                        │
```

### 2.2 目录结构

```
OpenClawTrader/
├── App/                          # App 入口
├── Features/
│   └── Profile/
│       └── OpenClawConnectView.swift   # 配对页面
├── Services/
│   └── PairingService.swift            # 配对服务
└── ...

~/openclaw/
├── relay-server/                 # 云端中继服务
│   ├── src/
│   │   ├── index.js              # 主入口
│   │   ├── api/
│   │   │   └── pair.js           # 配对 API
│   │   ├── relay/
│   │   │   ├── gateway.js        # Gateway 连接管理
│   │   │   └── device.js         # 设备连接管理
│   │   └── utils/
│   │       └── codeGen.js        # 配对码生成
│   └── relay-client/              # 桌面端中继客户端
│       ├── index.js              # RelayClient 类
│       └── cli.js                # CLI 命令
└── clawred/                      # ClawRed 安装脚本
    └── install.sh
```

---

## 3. 开发环境

### 3.1 iOS 开发环境
- **Xcode**: 15.0+
- **iOS 版本**: iOS 17.0+
- **Swift 版本**: 5.9+

### 3.2 云端服务开发环境
- **Node.js**: >= 18.0.0
- **包管理**: npm

### 3.3 本地服务启动

```bash
# 启动云端中继服务
cd ~/openclaw/relay-server
npm install
npm start

# 桌面端生成配对码
cd ~/openclaw/relay-server
npm run pair
```

---

## 4. 云端中继服务

### 4.1 服务地址

| 环境 | API 地址 | WebSocket 地址 |
|------|----------|----------------|
| 生产环境 | `http://150.158.119.114:3001/api` | `ws://150.158.119.114:3001` |

### 4.2 API 接口

#### 生成配对码
```
POST /api/pair/generate
```

**请求体**: (可选)
```json
{
  "gatewayId": "gateway-xxx"
}
```

**响应**:
```json
{
  "code": "K8GC5V",
  "expiresAt": "2026-03-28T12:05:00.000Z",
  "serverUrl": "ws://150.158.119.114:3001",
  "token": "device-xxx"
}
```

#### 验证配对码
```
POST /api/pair/verify
```

**请求体**:
```json
{
  "code": "K8GC5V"
}
```

**响应**:
```json
{
  "success": true,
  "gatewayToken": "gateway-token-xxx",
  "gatewayId": "gateway-xxx",
  "error": null
}
```

### 4.3 WebSocket 消息协议

| 消息类型 | 方向 | 说明 |
|----------|------|------|
| `gateway` | 桌面端→服务端 | 注册 Gateway |
| `device` | 移动端→服务端 | 注册设备 |
| `message` | 双向 | 消息转发 |
| `ping/pong` | 双向 | 心跳检测 |
| `registered` | 服务端→客户端 | 注册确认 |
| `device_connected` | 服务端→桌面端 | 设备连接通知 |
| `device_disconnected` | 服务端→桌面端 | 设备断开通知 |

### 4.4 配对码生成规则

- 长度: 6 位
- 字符集: 大写字母 + 数字（排除 0, O, I, L 等易混淆字符）
- 有效期: 5 分钟
- 格式: `XXXXXX` (如 `K8GC5V`)

---

## 5. 移动端配对流程

### 5.1 配对 URL 格式

桌面端生成的配对 URL:
```
openclaw://pair?code=K8GC5V&server=ws://150.158.119.114:3001
```

### 5.2 配对流程图

```
┌──────────┐                    ┌──────────┐                    ┌──────────┐
│  iOS App │                    │ Cloud    │                    │ Desktop  │
│          │                    │ Relay    │                    │ Gateway  │
└────┬─────┘                    └────┬─────┘                    └────┬─────┘
     │                              │                              │
     │  1. 扫描二维码               │                              │
     │ ──────────────────────────► │                              │
     │                              │                              │
     │                              │  2. 桌面端注册               │
     │                              │ ◄──────────────────────────── │
     │                              │                              │
     │  3. 输入配对码 K8GC5V         │                              │
     │ ──────────────────────────► │                              │
     │                              │                              │
     │                              │  4. 验证配对码               │
     │                              │ ◄──────────────────────────► │
     │                              │                              │
     │  5. 验证成功，返回 token      │                              │
     │ ◄──────────────────────────── │                              │
     │                              │                              │
     │  6. 保存 token 到 Keychain   │                              │
     │                              │                              │
     │  7. 配对完成                 │                              │
     │                              │                              │
```

### 5.3 核心代码

#### PairingService.swift

```swift
@MainActor
class PairingService: ObservableObject {
    static let shared = PairingService()

    private let relayAPI = "http://150.158.119.114:3001/api"
    private let relayWS = "ws://150.158.119.114:3001"

    /// 解析配对 URL
    /// 格式: openclaw://pair?code=XXX&server=ws://...
    func parsePairingURL(_ urlString: String) -> (code: String, server: String)? {
        guard let components = URLComponents(string: urlString),
              components.scheme == "openclaw",
              components.host == "pair" else {
            return nil
        }
        // ... 解析 queryItems
    }

    /// 验证配对码
    func verifyPairingCode(_ code: String) async -> VerifyResponse? {
        // POST /api/pair/verify
    }

    /// 执行配对流程
    func pairWithURL(_ urlString: String) async -> Bool {
        // 解析 URL → 验证配对码 → 保存 token
    }
}
```

#### OpenClawConnectView.swift

```swift
struct OpenClawConnectView: View {
    @StateObject private var pairingService = PairingService.shared

    var body: some View {
        // 扫码入口
        Button("扫码") {
            showScanner = true
        }

        // 手动输入入口
        Button("手动输入") {
            showManualInput = true
        }
    }

    // 处理扫描到的二维码
    private func handleScannedCode(_ code: String) {
        if let parsed = pairingService.parsePairingURL(code) {
            verifyCode(parsed.code)
        }
    }

    // 验证配对码
    private func verifyCode(_ code: String) {
        Task {
            if let response = await pairingService.verifyPairingCode(code), response.success {
                isPaired = true
            }
        }
    }
}
```

---

## 6. 核心模块说明

### 6.1 PairingService

**位置**: `Services/PairingService.swift`

**职责**:
- 调用云端 API 生成配对码
- 解析配对 URL
- 验证配对码
- 管理配对状态
- Keychain 存储 token

**关键类型**:

```swift
struct GenerateResponse: Codable {
    let code: String
    let expiresAt: String
    let serverUrl: String
    let token: String
}

struct VerifyResponse: Codable {
    let success: Bool
    let gatewayToken: String?
    let gatewayId: String?
    let error: String?
}
```

### 6.2 QRScannerViewController

**位置**: `OpenClawConnectView.swift` (内嵌类)

**职责**:
- 摄像头 QR 码扫描
- 扫描框 UI 定制
- 扫描结果回调

### 6.3 RelayClient (桌面端)

**位置**: `~/openclaw/relay-server/relay-client/index.js`

**职责**:
- 连接云端 WebSocket
- 注册 Gateway
- 消息转发到本地 AI
- 心跳维持连接

### 6.4 PairingCLI (桌面端)

**位置**: `~/openclaw/relay-server/relay-client/cli.js`

**命令**:
```bash
npm run pair        # 生成配对码并显示二维码
npm run connect     # 连接到云端中继服务
npm run status      # 查看连接状态
```

---

## 7. 构建与部署

### 7.1 iOS App 构建

```bash
cd OpenClawTrader/OpenClawTrader

# 构建 Debug 版本
xcodebuild -scheme OpenClawTrader -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 构建 Release 版本
xcodebuild -scheme OpenClawTrader -configuration Release \
  -destination 'generic/platform=iOS' build
```

### 7.2 云端中继服务部署

```bash
cd ~/openclaw/relay-server

# 安装依赖
npm install

# 开发环境运行
npm run dev

# 生产环境运行
npm start

# 使用 PM2 后台运行
pm2 start src/index.js --name openclaw-relay
```

### 7.3 常见问题

**Q: 配对码过期怎么办？**
A: 桌面端重新运行 `npm run pair` 生成新的配对码。

**Q: WebSocket 连接断开？**
A: RelayClient 会自动重连，最多重试 10 次。

**Q: iOS 扫描不到二维码？**
A: 确保相机权限已授权，检查二维码是否在扫描框内。

---

## 附录

### A. 颜色系统

| 名称 | 用途 |
|------|------|
| `accent` | 主题色/强调色 |
| `background` | 背景色 |
| `textPrimary` | 主要文字 |
| `textSecondary` | 次要文字 |
| `textTertiary` | 辅助文字 |

### B. 间距系统

| 名称 | 值 |
|------|-----|
| `xs` | 4pt |
| `sm` | 8pt |
| `md` | 16pt |
| `lg` | 24pt |
| `xl` | 32pt |

### C. 相关文档

- [项目结构](./OpenClawTrader/项目结构.md)
- [设计规范](./OpenClawTrader_DesignSpec.md)
- [产品需求](./OpenClawTrader_PRDT.md)
- [代码开发规范](./CODING_GUIDELINES.md)
- [提交规范](./COMMIT_GUIDELINES.md)

---

*文档版本: v1.0*
*创建日期: 2026-03-28*
*最后更新: 2026-03-28*
