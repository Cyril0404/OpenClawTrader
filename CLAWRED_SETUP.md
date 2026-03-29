# ClawRed 桌面端配对指南

## 概述

ClawRed 是 OpenClaw 桌面端的配对客户端，负责：
1. 生成配对码并显示二维码
2. 连接到云端 relay server
3. 注册 Gateway 身份

---

## 前置条件

- Node.js >= 18.0.0
- 已在桌面端安装 OpenClaw
- relay-server 已在云端部署并运行（端口 3001）

---

## 快速开始

### 1. 克隆/更新代码

```bash
cd ~/openclaw/relay-server
git pull  # 如果已有代码
npm install
```

### 2. 生成配对码

```bash
npm run pair
```

这会：
1. 连接到 relay server
2. 注册 Gateway 身份
3. 生成 6 位配对码
4. 显示二维码（终端内）
5. 持续运行直到 Ctrl+C

**示例输出**：
```
[RelayClient] Connecting to ws://150.158.119.114:3001...
[RelayClient] Connected
[Gateway] Registered as gateway: desktop-gw-001

✅ 配对码已生成！

   ╔══════════════════════════════╗
   ║         配 对 码             ║
   ║                              ║
   ║         K8GC5V              ║
   ║                              ║
   ╚══════════════════════════════╝

📱 请使用妙股App扫码配对
⏰ 有效期：5分钟

[QR Code displayed below]
```

### 3. iOS 端扫码

1. 打开妙股 App（OpenClawTrader）
2. 进入「我的」→「OpenClaw 连接」
3. 点击「扫码配对」
4. 对准终端中显示的二维码

### 4. 配对成功确认

iOS 扫码验证成功后，终端会收到通知：
```
[Device] New device connected: device-xxx
```

---

## 连接模式详解

### 独立运行模式（当前使用）

```bash
npm run pair
```

- 自动生成配对码
- 自动注册 Gateway
- 显示二维码
- **不会**自动连接到本地 AI

### 完整连接模式

```bash
npm run connect
```

- 连接到 relay server
- 注册 Gateway 身份
- 等待 iOS 设备连接
- 自动转发消息到本地 AI（如果配置了）

### 手动模式

```bash
node src/relay-client/cli.js pair
```

---

## 配置文件

连接参数可在 `package.json` 或环境变量中配置：

```json
{
  "scripts": {
    "pair": "node src/relay-client/cli.js pair",
    "connect": "node src/relay-client/cli.js connect"
  }
}
```

**环境变量**：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `RELAY_HOST` | `ws://150.158.119.114:3001` | relay server 地址 |
| `GATEWAY_ID` | 自动生成 | Gateway 唯一 ID |
| `DEBUG` | `false` | 调试日志 |

---

## 故障排查

### 连接失败

**错误**：`[RelayClient] Connection failed:ECONNREFUSED`

**原因**：relay server 未运行

**解决**：
```bash
# 在服务器上启动 relay server
pm2 start pm2.config.js
```

---

### 配对码不出现

**检查**：
1. `npm run pair` 输出中是否有 `[RelayClient] Connected`？
2. 是否有 `[Gateway] Registered` 日志？

```bash
# 查看详细日志
DEBUG=relay-client npm run pair
```

---

### iOS 扫码失败

**检查**：
1. 二维码是否在终端窗口内（没有被截断）？
2. 相机权限是否授权？
3. 配对码是否已过期（5分钟）？

**解决**：重新运行 `npm run pair` 生成新码

---

### Gateway ID 问题

**错误**：`gateway unknown`

**原因**：自动选择 Gateway 时 `gatewayManager.keys()` 返回的是 Iterator

**解决**：已在 relay-server >= 2026-03-29 版本修复

---

## 与 gateway-bridge.js 的关系

`relay-client/cli.js` 是 relay-server 包内的官方客户端，而 `~/openclaw/gateway-bridge.js` 是早期独立版本。

**推荐使用**：
- 新项目用 `npm run pair`（relay-server 自带）
- 已有 gateway-bridge 配置的可以继续用

两者功能相同，不能同时运行。

---

## 相关文档

- [ARCHITECTURE.md](./docs/ARCHITECTURE.md) - 系统架构
- [PAIRING_TROUBLESHOOTING.md](./docs/PAIRING_TROUBLESHOOTING.md) - 配对问题排查
- [PROBLEM_LOG.md](./docs/PROBLEM_LOG.md) - 问题解决记录

---

*文档版本: v1.0*
*最后更新: 2026-03-29*
