# OpenClawTrader 系统架构

## 1. 整体架构

### 1.1 三层架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          OpenClawTrader 系统架构                         │
└─────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐     ┌──────────────────┐     ┌──────────────────────┐
  │              │     │                  │     │                      │
  │   iOS App    │◄───►│   Cloud Relay    │◄───►│   Desktop Gateway    │
  │   (移动端)   │     │   Server         │     │   (桌面端)            │
  │              │     │  (腾讯云 3001)    │     │                      │
  │  配对扫码     │     │                  │     │  OpenClaw Gateway    │
  │  消息收发     │     │  WebSocket 中继   │     │  ClawRed (Mac/Win)   │
  │  AI 对话     │     │  配对码管理       │     │                      │
  │              │     │                  │     │                      │
  └──────────────┘     └──────────────────┘     └──────────────────────┘
         │                      │                        │
         │  HTTPS REST API       │  WebSocket             │
         │  POST /api/pair/*    │  ws://150.158.119.114   │
         │ ─────────────────────►│ ─────────────────────► │
         │                       │                        │
         │  WebSocket 连接        │  设备注册              │
         │ ◄──────────────────── │ ◄──────────────────── │
         │                       │                        │
```

### 1.2 组件职责

| 组件 | 技术栈 | 职责 |
|------|--------|------|
| **iOS App** | SwiftUI + AVFoundation | 扫码配对、消息收发、AI对话入口 |
| **Cloud Relay Server** | Node.js + Express + ws | 配对码管理、WebSocket路由消息 |
| **Desktop Gateway** | Node.js (OpenClaw) | 本地AI连接、消息处理 |
| **ClawRed** | Node.js CLI | 桌面端配对码生成、二维码显示 |

### 1.3 数据流向

```
用户发消息（iOS）
      │
      ▼
iOS App → WebSocket → Relay Server
      │                        │
      │                        ▼
      │              根据 token 查找对应 Gateway
      │                        │
      ▼                        ▼
Relay Server ← WebSocket ← Desktop Gateway
      │
      ▼
Gateway → 本地 AI（Ollama/Claude）
      │
      ▼
AI 响应原路返回 iOS
```

---

## 2. 目录结构

```
OpenClawTrader/
├── iOS/                              # iOS App 源代码
│   ├── OpenClawTrader.xcodeproj/    # Xcode 项目
│   ├── App/                          # App 入口
│   ├── Features/                     # 功能模块
│   │   └── Profile/
│   │       └── OpenClawConnectView.swift  # 配对页面
│   ├── Services/
│   │   └── PairingService.swift      # 配对服务
│   ├── Models/                       # 数据模型
│   └── Resources/                    # 资源文件
│
├── relay-server/                     # 云端中继服务（Node.js）
│   ├── src/
│   │   ├── index.js                  # 主入口（HTTP + WebSocket）
│   │   ├── api/
│   │   │   └── pair.js               # 配对 API（生成/验证码）
│   │   ├── relay/
│   │   │   ├── gateway.js            # Gateway 连接管理
│   │   │   └── device.js             # 设备连接管理
│   │   ├── shared/
│   │   │   └── tokenRegistry.js      # token → gatewayId 映射（内存+文件）
│   │   ├── utils/
│   │   │   └── codeGen.js            # 配对码生成工具
│   │   └── relay-client/
│   │       ├── index.js              # RelayClient 类（桌面端用）
│   │       └── cli.js                # CLI 命令（pair/connect）
│   ├── data/                         # 持久化数据
│   │   ├── pairing-codes.json        # 配对码存储
│   │   └── tokens.json               # token 映射存储
│   └── pm2.config.js                 # PM2 部署配置
│
├── docs/                             # 文档
│   ├── ARCHITECTURE.md               # 本文档
│   ├── PAIRING_TROUBLESHOOTING.md    # 配对问题排查
│   ├── PROBLEM_LOG.md                # 问题解决记录
│   └── RELAY_SERVER.md               # relay-server 部署指南
│
├── CHANGELOG.md                       # 变更日志
├── DEVELOPMENT.md                    # 开发手册
├── OPENCLAWCONNECT_ISSUES.md         # 配对问题汇总
├── CLAWRED_SETUP.md                  # ClawRed 桌面端配对指南
└── README.md                          # 项目总览
```

---

## 3. 配对流程详解

配对流程分为 **5 个步骤**，涉及 iOS App、Cloud Relay Server、Desktop Gateway 三个组件。

### 配对 URL 格式

桌面端生成的配对 URL：
```
openclaw://pair?code=XXXXXX&server=ws://150.158.119.114:3001
```

### 步骤详解

```
┌──────────┐                    ┌──────────────┐                    ┌──────────┐
│ iOS App  │                    │ Cloud Relay  │                    │ Desktop  │
│          │                    │   Server     │                    │ Gateway  │
└────┬─────┘                    └──────┬───────┘                    └────┬─────┘
     │                                │                                │
     │                                │                                │
     │                                │◄────── 1. Gateway 注册 ────────│
     │                                │   {type:"gateway",gatewayId}   │
     │                                │                                │
     │  2. 扫描二维码 / 手动输入        │                                │
     │ ─────────────────────────────► │                                │
     │   openclaw://pair?code=XXX     │                                │
     │                                │                                │
     │                                │ 3. 配对码写入 pairingCodesMap   │
     │                                │    token → gatewayId 写入       │
     │                                │    tokens.json 持久化           │
     │                                │                                │
     │  4. POST /api/pair/verify      │                                │
     │   {code: "XXXXXX"}             │                                │
     │ ─────────────────────────────► │                                │
     │                                │                                │
     │                                │ 5. 验证成功                     │
     │                                │   - 删除配对码（一次性）        │
     │                                │   - 返回 gatewayToken           │
     │                                │   - 写入 tokens.json           │
     │                                │                                │
     │  验证成功，返回 gatewayToken     │                                │
     │ ◄───────────────────────────── │                                │
     │                                │                                │
     │  6. WebSocket 连接              │                                │
     │   {type:"device",token:xxx}     │                                │
     │ ─────────────────────────────► │                                │
     │                                │                                │
     │                                │ 7. 根据 token 查找 gatewayId    │
     │                                │   从 tokens.json 读取          │
     │                                │                                │
     │                                │ 8. 通知 Desktop Gateway        │
     │                                │   {type:"device_connected"}    │
     │                                │ ─────────────────────────────► │
     │                                │                                │
     │  连接成功                       │                                │
     │ ◄───────────────────────────── │                                │
     │                                │                                │
     │  配对完成✅                     │                                │
     │                                │                                │
```

### 关键数据结构

**配对码存储** (`pairing-codes.json`):
```json
{
  "K8GC5V": {
    "gatewayId": "gw-xxx",
    "token": "temp-token",
    "createdAt": "2026-03-29T10:00:00Z",
    "expiresAt": "2026-03-29T10:05:00Z"
  }
}
```

**Token 映射** (`tokens.json`):
```json
{
  "gatewayToken-xxx": "gw-xxx",
  "temp-token-xxx": "gw-xxx"
}
```

---

## 4. WebSocket 消息协议

### 4.1 消息类型总览

| type | 方向 | 说明 |
|------|------|------|
| `gateway` | 桌面端 → 服务端 | Gateway 注册 |
| `device` | 移动端 → 服务端 | Device 注册 |
| `message` | 双向 | 业务消息转发 |
| `ping` / `pong` | 双向 | 心跳检测 |
| `registered` | 服务端 → 客户端 | 注册确认 |
| `device_connected` | 服务端 → 桌面端 | 设备已连接通知 |
| `device_disconnected` | 服务端 → 桌面端 | 设备断开通知 |
| `gateway_disconnected` | 服务端 → 移动端 | Gateway 断开通知 |
| `error` | 服务端 → 客户端 | 错误消息 |

### 4.2 Gateway 注册

```javascript
// Desktop → Relay Server
{
  "type": "gateway",
  "gatewayId": "desktop-gw-001"
}

// Relay Server → Desktop
{
  "type": "registered",
  "role": "gateway",
  "gatewayId": "desktop-gw-001"
}
```

### 4.3 Device 注册

```javascript
// iOS → Relay Server
{
  "type": "device",
  "token": "gatewayToken-from-verify-api"
}

// Relay Server → iOS
{
  "type": "registered",
  "role": "device",
  "gatewayId": "desktop-gw-001"
}
```

### 4.4 消息收发

```javascript
// iOS → Desktop
{
  "type": "message",
  "content": "今天大盘怎么样？"
}

// Desktop → iOS
{
  "type": "message",
  "from": "gateway",
  "content": "今天上证指数上涨0.5%..."
}
```

---

## 5. 安全考量

1. **配对码一次性使用**：验证后立即删除，防止重放攻击
2. **5 分钟过期**：配对码有效期短暂，减少被盗用风险
3. **Token 映射持久化**：服务重启后 token 仍然有效
4. **无密码认证**：依赖临时 token + 配对码的组合认证

---

*文档版本: v1.0*
*最后更新: 2026-03-29*
