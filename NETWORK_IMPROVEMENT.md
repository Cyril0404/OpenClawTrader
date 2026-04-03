# OpenClawTrader 网络编程改进方案

> 基于 codecrafters 网络编程（Beej's Guide / TCP-IP Stack）知识落地
> 整理时间：2026-04-02

---

## 背景

OpenClawTrader 通过 relay-server（腾讯云 WebSocket）中继与 OpenClaw Gateway 通信。iOS App 作为 WebSocket 客户端，连接稳定性直接影响 AI 对话体验。

当前已知问题：**Gateway WebSocket 连接不稳定，会断线，且重连逻辑缺失。**

---

## 问题分析

### 当前 WebSocket 实现架构

```
iOS App (WebSocketChatService)
    ↓ WebSocket (URLSessionWebSocketTask)
relay-server (150.158.119.114:3001)
    ↓ WebSocket
OpenClaw Gateway (本地 Mac Mini)
```

### 根本问题识别

#### 问题 1：断线后没有任何重连机制（致命）

**代码位置：** `WebSocketChatService.swift` 的 `receiveMessage()`

```swift
// 当前逻辑：
private func receiveMessage() {
    webSocketTask?.receive { [weak self] result in
        switch result {
        case .success(let message):
            self?.receiveMessage()  // ← 成功时递归，继续收下一条
        case .failure(let error):
            // 断线时只设置 isConnected = false，没有重连！
            Task { @MainActor in
                self?.isConnected = false
                self?.errorMessage = "连接断开: \(error.localizedDescription)"
            }
            // ← 函数到此为止，递归链断了，不会再收到消息
        }
    }
}
```

**Beej's Guide 网络编程启示：** TCP 是有状态的字节流连接，断开是正常状态而不是异常状态。**任何长时间运行的 TCP 客户端都必须实现重连逻辑**，这是 TCP 网络编程的铁律。

**后果：**
- 网络抖动（切换 Wi-Fi/4G、信号弱）→ 连接永久断开
- Gateway 重启 → App 不会自动重连
- 用户必须手动重开 App 才能恢复

#### 问题 2：没有心跳保活机制（严重）

**问题：** TCP 连接空闲时，中间设备（路由器/NAT/云服务器）会关闭空闲连接，通常 30-60 秒内。

**当前代码：** `URLSessionWebSocketTask` 默认会发送 WebSocket ping，但：
- 没有显式处理 pong 超时
- 没有检测 pong 超时后的主动重连
- `receiveMessage()` 递归链断裂时，ping/pong 机制也随之中断

**Beej's Guide 启示：** TCP keepalive 和应用层心跳是两种不同的保活机制，必须同时启用。

#### 问题 3：URLSession 配置是 default，没有针对长连接优化

```swift
// 当前代码
urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
```

**问题：**
- `URLSessionConfiguration.default` 没有针对 WebSocket 长连接优化
- 没有设置 `waitsForConnectivity`，蜂窝网络切换时不会等待
- 没有设置合理的 timeout

#### 问题 4：没有连接状态机，reconnect 时序混乱

**当前代码：** `connect()` 和 `disconnect()` 没有任何锁，`isConnected` 和 `webSocketTask` 状态可能不一致。

---

## 改进方案

### 改进 1：实现指数退避重连（Exponential Backoff）

**核心原则：** 断线后不要立刻重连，而是等待一段时间。重连失败则加倍等待，最多重试到某个上限。

```swift
// 新增属性
private var reconnectAttempts = 0
private let maxReconnectAttempts = 10
private let baseReconnectDelay: TimeInterval = 1.0  // 1秒
private let maxReconnectDelay: TimeInterval = 60.0 // 最多等60秒
private var isReconnecting = false

// 新增方法
private func scheduleReconnect() {
    guard reconnectAttempts < maxReconnectAttempts else {
        print("[WSChat] Max reconnect attempts reached, giving up")
        Task { @MainActor in
            self.errorMessage = "连接失败，请检查网络后重试"
        }
        return
    }

    isReconnecting = true
    reconnectAttempts += 1

    // 指数退避公式：delay = min(base * 2^attempts + random_jitter, maxDelay)
    let delay = min(
        baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)),
        maxReconnectDelay
    )
    let jitter = Double.random(in: 0...0.5)
    let actualDelay = delay + jitter

    print("[WSChat] Scheduling reconnect #\(reconnectAttempts) in \(actualDelay)s")

    Task {
        try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.performReconnect()
        }
    }
}

private func performReconnect() {
    guard let url = URL(string: relayURL) else { return }
    print("[WSChat] Reconnecting to \(relayURL)...")

    webSocketTask = urlSession.webSocketTask(with: url)
    webSocketTask?.resume()
    isConnected = false  // 等 registered 事件再设为 true
    receiveMessage()

    // 超时保护：5秒内没收到 registered 就认为重连失败
    Task {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        if !isConnected {
            print("[WSChat] Reconnect timeout, scheduling next attempt")
            scheduleReconnect()
        }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.sendRegister()
    }
}
```

**Beej's Guide 启示：** 指数退避是 TCP 协议族（RCP、802.11、TCP 自己都用）的标准重连策略。目的是避免在网络恢复时大量客户端同时重连造成拥塞。

### 改进 2：添加 WebSocket ping/pong 心跳 + 超时检测

```swift
// 心跳定时器
private var pingTask: Task<Void, Never>?
private let pingInterval: TimeInterval = 25.0  // 每25秒发一次

private func startHeartbeat() {
    pingTask?.cancel()
    pingTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
            guard !Task.isCancelled else { break }
            await MainActor.run {
                self.sendPing()
            }
        }
    }
}

private func sendPing() {
    webSocketTask?.sendPing { [weak self] error in
        Task { @MainActor in
            if let error = error {
                print("[WSChat] Ping failed: \(error), scheduling reconnect")
                self?.handleDisconnection()
            }
        }
    }
}

private func handleDisconnection() {
    isConnected = false
    webSocketTask?.cancel(with: .goingAway, reason: nil)
    webSocketTask = nil
    pingTask?.cancel()
    pingTask = nil

    if !isReconnecting {
        scheduleReconnect()
    }
}
```

**在 `receiveMessage()` 的 failure 分支里调用 `handleDisconnection()` 而不是直接设置状态：**

```swift
case .failure(let error):
    print("[WSChat] Receive error: \(error)")
    Task { @MainActor in
        self.handleDisconnection()  // ← 触发重连，而不是只设置状态
    }
```

### 改进 3：优化 URLSession 配置

```swift
// 在 init() 里替换为
let config = URLSessionConfiguration.default
config.waitsForConnectivity = true      // 等待网络切换（Wi-Fi↔蜂窝）
config.timeoutIntervalForRequest = 30    // 单次请求30秒超时
config.timeoutIntervalForResource = 60  // 整个资源操作60秒超时
config.keepAliveInterval = 30           // TCP keepalive 每30秒
config.httpAdditionalHeaders = [
    "Connection": "keep-alive"
]
urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
```

### 改进 4：添加连接锁，防止并发重连

```swift
private var connectionLock = NSLock()
private var currentState: ConnectionState = .disconnected

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

func connect(baseURL: String, token: String) {
    connectionLock.lock()
    defer { connectionLock.unlock() }

    guard currentState == .disconnected else {
        print("[WSChat] Already connecting/connected, ignoring duplicate connect()")
        return
    }
    currentState = .connecting

    // ... 原有连接逻辑 ...
}
```

### 改进 5：断线时保留并恢复 pendingMessages（重要）

**问题：** 当前如果用户发了一条消息后连接断开，`pendingMessages[id]` 会泄漏，用户永远收不到回调。

**方案：** 断开时记录 pending 消息，重连后自动重发：

```swift
private var pendingMessages: [String: (String?) -> Void] = [:]
private var unacknowledgedMessageIds: Set<String> = []  // 新增

// 断开时
private func handleDisconnection() {
    // ... 取消 ping/连接 ...
    // 记录还没收到响应的消息 ID
    unacknowledgedMessageIds = Set(pendingMessages.keys)
    pendingMessages.removeAll()
}

// 重连成功收到 registered 后
case "registered":
    self.isConnected = true
    self.currentState = .connected
    self.reconnectAttempts = 0
    self.errorMessage = nil

    // 重发未确认的消息
    for id in unacknowledgedMessageIds {
        print("[WSChat] Resending unacknowledged message: \(id)")
        // 从 App 层面重新发，需要调用方配合
        NotificationCenter.default.post(name: .wsResendMessage, object: id)
    }
    unacknowledgedMessageIds.removeAll()
```

> **注：** 这需要上层 Chat View 配合，在收到重发通知时重新调用 `sendChatMessage()`。

---

## 完整重连状态机

```
[disconnected] --connect()--> [connecting] --registered--> [connected]
                                        |                        |
                                        v (失败/断线)            v (失败/断线)
                                 [reconnecting] <------- [connected]
                                        |
                                        v (重连成功)
                                  [connected]
```

---

## 总结

| 改进点 | 严重程度 | 改动范围 | 预期效果 |
|--------|---------|---------|---------|
| 1. 指数退避重连 | 🔴 致命 | WebSocketChatService 新增方法 | 网络抖动后自动恢复 |
| 2. ping/pong 心跳 | 🔴 严重 | WebSocketChatService 修改 | NAT/防火墙超时不再断开 |
| 3. URLSession 优化 | 🟡 中等 | init() 配置 | 连接可靠性提升 |
| 4. 连接锁防并发 | 🟡 中等 | connect/disconnect | 避免竞态条件 |
| 5. pending 消息恢复 | 🟡 中等 | handleDisconnection + registered | 断线重连后消息不丢失 |

**实施顺序建议：** 先做改进 1+2（核心重连机制），再叠加改进 3（配置优化），最后做 4+5（健壮性增强）。
