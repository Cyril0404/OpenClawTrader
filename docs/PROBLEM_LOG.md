# OpenClawTrader 问题解决记录

> 记录开发过程中遇到的关键问题及其解决方案。
> 最后更新：2026-03-29

---

## 问题 1：gateway unknown（Array.from bug）

**日期**: 2026-03-29

**影响文件**: `relay-server/src/api/pair.js`

**问题描述**:
生成配对码时，如果未指定 `gatewayId`，代码尝试从 `gatewayManager.keys()` 自动选择，但报错 `gateway unknown`。

**根本原因**:
`gatewayManager.keys()` 返回一个 **Iterator**（迭代器），不是数组。Iterator 没有 `.length` 属性，也没有数组索引访问方式。

```javascript
// ❌ 错误代码
const availableGateways = gatewayManager ? gatewayManager.keys() : []
const selectedGatewayId = gatewayId || (availableGateways.length > 0 ? availableGateways[0] : null)
```

`availableGateways.length` 返回 `undefined`，导致条件判断异常。

**修复方案**:
使用展开运算符将 Iterator 转为数组：

```javascript
// ✅ 正确代码
const availableGateways = gatewayManager ? [...gatewayManager.keys()] : []
const selectedGatewayId = gatewayId || (availableGateways.length > 0 ? availableGateways[0] : null)
```

**教训**: Node.js 的 `Map.keys()`、`Map.values()`、`Map.entries()` 都返回迭代器，任何使用数组方法的场景都需要显式转换。

---

## 问题 2：tokenToGatewayId Map 重启丢失

**日期**: 2026-03-29

**影响文件**: `relay-server/src/shared/tokenRegistry.js`

**问题描述**:
验证配对码成功后，`tokenToGatewayId` Map 中注册了 `gatewayToken → gatewayId` 映射。但 relay server 重启后，Map 被清空，导致已配对设备的 WebSocket 连接无法找到对应的 Gateway。

**根本原因**:
`tokenToGatewayId` Map 存储在内存中，没有任何持久化机制。

```javascript
// ❌ 只有内存存储
const tokenToGatewayId = new Map()
```

**修复方案**:
添加 `tokens.json` 文件持久化：

```javascript
const fs = require('fs')
const path = require('path')
const TOKENS_FILE = path.join('/Users/zifanni/openclaw/relay-server/data', 'tokens.json')

// 从文件加载
function loadTokens() {
  try {
    if (fs.existsSync(TOKENS_FILE)) {
      const data = JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf8'))
      Object.entries(data).forEach(([token, gatewayId]) => {
        tokenToGatewayId.set(token, gatewayId)
      })
      console.log(`[TokenRegistry] Loaded ${tokenToGatewayId.size} tokens from disk`)
    }
  } catch (e) {
    console.log('[TokenRegistry] Failed to load tokens:', e.message)
  }
}

// 保存到文件
function saveTokens() {
  try {
    const data = Object.fromEntries(tokenToGatewayId)
    fs.writeFileSync(TOKENS_FILE, JSON.stringify(data, null, 2), 'utf8')
  } catch (e) {
    console.log('[TokenRegistry] Failed to save tokens:', e.message)
  }
}
```

在 `registerToken` 函数中调用 `saveTokens()`。

**教训**: 任何需要在服务重启后保持状态的数据结构，都必须有持久化机制。对于小型数据，JSON 文件足够；大型数据考虑 Redis/SQLite。

---

## 问题 3：verify 成功但码被删了导致第二次无效

**日期**: 2026-03-29

**影响文件**: `relay-server/src/api/pair.js`

**问题描述**:
用户用配对码扫码验证成功后，再次用同一个码扫码，提示"配对码无效"。

**分析**:
这是**预期行为**，不是 bug。配对码设计为一次性使用：
- 验证成功后，配对码立即从 `pairingCodesMap` 中删除
- 每次配对需要重新生成新的配对码

```javascript
// pair.js 中的 verify 处理
// 删除已使用的配对码（一次性）
pairingCodesMap.delete(code)
```

**如果需要支持多次验证**（例如：用户扫码后超过5分钟连接失败）：
- 需要在 `pair.js` 中增加一个选项，允许多次验证
- 或者延长配对码有效期（但增加安全风险）

**当前结论**: 保持一次性使用设计，用户需重新运行 `npm run pair` 生成新码。

---

## 问题 4：gateway-bridge 没连上 relay

**日期**: 2026-03-29

**影响文件**: `~/openclaw/gateway-bridge.js`（桌面端）

**问题描述**:
iOS App 验证配对码成功，但 WebSocket 连接后收不到 `device_connected` 通知。查看 relay server 日志，发现桌面端 gateway 未注册。

**排查过程**:
1. `pm2 status` → relay server 正在运行 ✅
2. `curl http://localhost:3001/health` → 健康 ✅
3. `pm2 logs openclaw-relay` → 没有 gateway 注册日志 ❌
4. 检查桌面端 `gateway-bridge.js` 进程 → 进程存在但未连接

**根本原因**:
`gateway-bridge.js` 与 relay server 的 WebSocket 连接断开了，但进程本身没有退出。

**修复方案**:
```bash
# 杀掉旧的 gateway-bridge 进程
pkill -f gateway-bridge

# 重新启动（连接到云端 relay）
node ~/openclaw/gateway-bridge.js

# 如果使用 relay-server 自带的 relay-client
cd ~/openclaw/relay-server
npm run connect
```

**验证**:
```bash
# 在 relay server 日志中应该看到：
# [Gateway] New gateway registered: desktop-gw-xxx
```

---

## 问题 5：pairingCodesMap 跨进程共享问题

**日期**: 2026-03-29

**影响文件**: `relay-server/src/api/pair.js`

**问题描述**:
如果同时运行多个 relay server 实例（或 relay-server 和 ClawRed CLI），配对码生成和验证的内存状态不共享。

**分析**:
`pairingCodesMap` 是进程内的 Map，不是共享存储。不同进程之间无法共享内存数据。

**解决**:
使用文件持久化作为跨进程共享机制：
```javascript
// 每次读取前从文件加载最新状态
loadPairingCodes()

// 每次写入后保存到文件
savePairingCodes()
```

这正是当前代码的实现方式。

---

## 问题 6：iOS 扫码 URL 解析失败

**日期**: 2026-03-29

**影响文件**: `iOS/Services/PairingService.swift`

**问题描述**:
iOS 扫描 `openclaw://pair?code=XXX&server=ws://...` 格式的二维码后，无法正确解析。

**排查**:
Swift 的 `URLComponents` 对自定义 scheme `openclaw://` 解析可能有问题。

**解决**:
确保使用 `URLComponents(parsing:)` 而不是 `URLComponents(string:)`：

```swift
guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme == "openclaw",
      components.host == "pair" else {
    return nil
}
```

---

## 相关文件路径

```
~/openclaw/
├── relay-server/                              # relay server 主目录
│   ├── src/
│   │   ├── index.js                          # 主入口
│   │   ├── api/pair.js                       # 配对 API（问题1,3,5）
│   │   └── shared/tokenRegistry.js           # Token 映射（问题2）
│   └── data/
│       ├── pairing-codes.json                # 配对码持久化
│       └── tokens.json                       # token 映射持久化
│
├── gateway-bridge.js                         # 桌面端 bridge（问题4）
│
└── OpenClawTrader/                           # iOS App（问题6）
    └── iOS/Services/PairingService.swift
```

---

## 调试技巧

### 实时查看 relay server 日志
```bash
pm2 logs openclaw-relay --follow
```

### 实时查看 gateway-bridge 日志
```bash
tail -f ~/openclaw/relay-server/logs/*.log
```

### 查看配对码和 token 状态
```bash
cat ~/openclaw/relay-server/data/pairing-codes.json | jq .
cat ~/openclaw/relay-server/data/tokens.json | jq .
```

---

*记录版本: v1.0*
*最后更新: 2026-03-29*
