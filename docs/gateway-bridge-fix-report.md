# OpenClaw Relay-Server Gateway-Bridge 修复报告

## 日期
2026-03-30

## 问题描述

iOS App 连接 OpenClaw Gateway 失败，显示"未连接"。WebSocket 注册成功但立即断开。

## 根因分析

### 问题1：PM2 运行在 cluster_mode
**现象**：PM2 以 cluster 模式运行，创建多个 worker 进程，每个进程有独立内存。

**影响**：
- gateway-bridge 连接 Worker 1
- iOS device 连接 Worker 2
- 两者状态不共享，无法通信

**修复**：改为 fork 模式
```bash
pm2 stop openclaw-relay
pm2 delete openclaw-relay
pm2 start src/index.js --name openclaw-relay --env development
```

### 问题2：Gateway 认证流程不正确
**现象**：
```
[GATEWAY] ❌ Connect failed: {"code":"INVALID_REQUEST","message":"unauthorized: gateway token mismatch..."}
```

**原因**：我们的 gateway-bridge 没有正确实现 OpenClaw Gateway 的认证流程。

## 参考实现

分析了 **ClawPilot** (@rethinkingstudio/clawpilot) 的 `gateway-client.js` 实现：

GitHub: https://github.com/Rethinking-studio/clawpilot-skills
npm: `@rethinkingstudio/clawpilot`

### ClawPilot 认证流程

1. **等待 Challenge**：WebSocket 连接后等待 `connect.challenge` 事件获取 nonce
2. **带 nonce 签名**：用 nonce + token 签名设备身份
3. **存储 deviceToken**：成功后从 `helloOk.auth.deviceToken` 提取并存储
4. **后续重连优先用 deviceToken**：避免重复认证
5. **完善 scopes**：`["operator.admin", "operator.read", "operator.write", "operator.approvals", "operator.pairing"]`

## 代码改动

### 文件：`/Users/zifanni/openclaw/relay-server/src/gateway-bridge.js`

#### 改动1：添加 deviceToken 存储
```javascript
// 存储 deviceToken（ClawPilot 风格）
this.storedDeviceToken = null;
this.connectTimer = null;
this.tickTimer = null;
this.lastTick = 0;
this.tickIntervalMs = 30_000;
```

#### 改动2：等待 challenge（1秒超时）
```javascript
this.gatewayWs.on('open', () => {
    log('GATEWAY', 'WebSocket opened, waiting for challenge...');
    this.connectNonce = null;
    this.connectSent = false;
    // ClawPilot 风格：1秒后如果没收到 challenge 也发送 connect
    this.connectTimer = setTimeout(() => this.sendGatewayConnect(), 1000);
});
```

#### 改动3：收到 challenge 后清除定时器并发送 connect
```javascript
if (msg.type === 'event' && msg.event === 'connect.challenge') {
    clearTimeout(timeout);
    if (this.connectTimer) {
        clearTimeout(this.connectTimer);
        this.connectTimer = null;
    }
    this.connectNonce = msg.payload?.nonce;
    log('GATEWAY', `Got challenge nonce: ${this.connectNonce}`);
    this.sendGatewayConnect();
    ...
}
```

#### 改动4：完善 sendGatewayConnect（ClawPilot 风格）
```javascript
sendGatewayConnect() {
    const role = 'operator';
    const scopes = ['operator.admin', 'operator.read', 'operator.write', 'operator.approvals', 'operator.pairing'];
    const clientId = 'openclaw-macos';
    const clientMode = 'ui';
    const signedAtMs = Date.now();
    const nonce = this.connectNonce ?? undefined;
    // ClawPilot 风格：优先用 storedDeviceToken
    const authToken = this.storedDeviceToken ?? this.gatewayToken;

    const signedDevice = buildSignedDevice(this.identity, {
        clientId, clientMode, role, scopes, signedAtMs,
        token: authToken ?? undefined,
        nonce,
    });

    const params = {
        minProtocol: 3,
        maxProtocol: 3,
        role,
        scopes,
        caps: ['tool-events'],
        client: {
            id: 'openclaw-macos',
            displayName: 'Macmini',
            version: '1.0.0',
            platform: process.platform,
            mode: clientMode,
        },
        device: signedDevice,
        auth: (authToken || this.gatewayToken)
            ? { token: authToken, password: this.gatewayToken }
            : undefined,
    };
    ...
}
```

#### 改动5：成功后存储 deviceToken
```javascript
this.pendingRequests.set(reqId, (res) => {
    ...
    if (res.ok) {
        // ClawPilot 风格：保存 deviceToken
        const deviceToken = res.payload?.auth?.deviceToken;
        if (typeof deviceToken === 'string') {
            this.storedDeviceToken = deviceToken;
            log('GATEWAY', `Stored deviceToken: ${deviceToken.substring(0, 8)}...`);
        }
        if (typeof res.payload?.policy?.tickIntervalMs === 'number') {
            this.tickIntervalMs = res.payload.policy.tickIntervalMs;
        }
        ...
    } else {
        log('GATEWAY', `❌ Connect failed: ${JSON.stringify(res.error)}`);
        // ClawPilot 风格：清除 deviceToken，下次用原始 token 重试
        this.storedDeviceToken = null;
        this.connectSent = false;
    }
});
```

#### 改动6：添加 tick watch（心跳检测）
```javascript
startTickWatch() {
    if (this.tickTimer) clearInterval(this.tickTimer);
    const interval = Math.max(this.tickIntervalMs, 1000);
    this.tickTimer = setInterval(() => {
        if (this.stopped || !this.lastTick) return;
        if (Date.now() - this.lastTick > this.tickIntervalMs * 2) {
            this.gatewayWs?.close(4000, 'tick timeout');
        }
    }, interval);
}
```

## 验证结果

### 重启 gateway-bridge 后日志
```
[05:15:52] [BRIDGE] Device ID: 70768f8c9247c132...
[05:15:52] [BRIDGE] Starting gateway bridge...
[05:15:52] [BRIDGE]   -> Relay:   ws://localhost:3001
[05:15:52] [BRIDGE]   -> Gateway: ws://127.0.0.1:18789
[05:15:52] [BRIDGE]   -> ID:      mac-mini-gw-2244
[05:15:52] [RELAY] Connected to relay server, registering as gateway...
[05:15:52] [RELAY] Registered as gateway: mac-mini-gw-2244
[05:15:52] [BRIDGE] Relay connected, connecting to Gateway...
[05:15:52] [GATEWAY] Connecting to OpenClaw Gateway...
[05:15:52] [GATEWAY] WebSocket opened, waiting for challenge...
[05:15:52] [GATEWAY] Got challenge nonce: 5b4f3bc0-a60e-458c-9132-221e572dc6b9
[05:15:52] [GATEWAY] Sending connect request...
[05:15:52] [BRIDGE] Gateway bridge is running!
[05:15:52] [GATEWAY] Stored deviceToken: qcOnv5y5...
[05:15:52] [GATEWAY] ✅ Connected to Gateway! (role=operator)
```

### relay-server health
```json
{"status":"ok","connections":{"gateway":1,"device":0}}
```

## 开发流程总结

### 1. 定位问题
- 检查 PM2 运行模式（cluster vs fork）
- 检查 gateway-bridge 日志
- 用 curl 测试 relay-server API

### 2. 分析参考实现
- 找同类产品（ClawPilot）分析其实现
- 对比关键代码差异

### 3. 修复步骤
1. PM2 改为 fork 模式
2. 重写 gateway-bridge 认证流程
3. 测试验证

### 4. 关键命令
```bash
# 查看 PM2 进程
pm2 list

# 查看 relay-server 日志
pm2 logs openclaw-relay --lines 50

# 测试 API
curl http://localhost:3001/health
curl -X POST http://localhost:3001/api/pair/generate -H "Content-Type: application/json" -d '{"gatewayId":"mac-mini-gw-2244"}'

# 重启 gateway-bridge
kill $(ps aux | grep gateway-bridge | grep -v grep | awk '{print $2}')
node /Users/zifanni/openclaw/relay-server/src/gateway-bridge.js --relay ws://localhost:3001 --url http://127.0.0.1:18789 --token <GATEWAY_TOKEN> --gateway-id mac-mini-gw-2244
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `/Users/zifanni/openclaw/relay-server/src/gateway-bridge.js` | 修改后的 gateway-bridge |
| `/Users/zifanni/openclaw/relay-server/src/index.js` | relay-server 主文件 |
| `/opt/homebrew/lib/node_modules/@rethinkingstudio/clawpilot/dist/relay/gateway-client.js` | ClawPilot 参考实现 |

## 后续建议

1. **将 gateway-bridge 改为长期运行的服务**，由 PM2 管理
2. **添加配置读取**，支持从配置文件读取 gateway token
3. **完善日志**，添加结构化日志便于排查问题
4. **添加 metrics**，监控连接状态和消息转发量
