import Foundation

// ============================================================
// WebSocketChatService — 通过 relay-server WebSocket 收发聊天消息
//
// 协议（参考 ClawPilot）：
//   1. 连接成功后发送 { type: "register", token: "<pairingToken>" }
//   2. 收到 { type: "registered", role: "device" } → 注册成功
//   3. 发消息: { type: "message", content: "{\"type\":\"req\",\"id\":\"...\",\"method\":\"chat.send\",\"params\":{\"message\":\"...\",\"deliver\":false}}" }
//   4. 收消息: { type: "message", from: "gateway", content: "..." } → 解析 event 事件
//   5. AI 响应通过 agent 事件 (stream: "assistant") 或 chat.push 事件推送
//
// 重连机制（参考 NETWORK_IMPROVEMENT.md）：
//   - 指数退避重连（Exponential Backoff）
//   - ping/pong 心跳 + 超时检测
//   - URLSession 优化配置
//   - 连接锁防止并发重连
//   - pending 消息重发
// ============================================================

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - WebSocketChatService

@MainActor
class WebSocketChatService: NSObject, ObservableObject {
    static let shared = WebSocketChatService()

    @Published var isConnected = false
    @Published var lastAIResponse: String?
    @Published var errorMessage: String?
    @Published var incomingMessages: [String] = []

    // Connection state machine
    @Published private(set) var currentState: ConnectionState = .disconnected

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var relayURL: String = ""
    private var deviceToken: String = ""
    private var pendingMessages: [String: (String?) -> Void] = [:]

    // 流式回调
    private var streamCallback: ((String) -> Void)?

    // 追踪是否已经有流式内容到达，避免 state==final 回调覆盖已 streaming 的内容
    private var hasStreamedContent = false

    // MARK: - Reconnection
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 60.0
    private var isReconnecting = false
    private var reconnectTask: Task<Void, Never>?

    // MARK: - Heartbeat
    private var pingTask: Task<Void, Never>?
    private let pingInterval: TimeInterval = 25.0

    // MARK: - Connection Lock
    private let connectionLock = NSLock()

    // MARK: - Pending message recovery
    private var unacknowledgedMessageIds: Set<String> = []

    // MARK: - Init

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpAdditionalHeaders = [
            "Connection": "keep-alive"
        ]
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    // MARK: - Public API

    func connect(baseURL: String, token: String) {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard currentState == .disconnected else {
            print("[WSChat] Already \(currentState), ignoring duplicate connect()")
            return
        }
        currentState = .connecting

        disconnectInternal()

        // baseURL 格式是 "http://150.158.119.114:3001/api"
        // relay-server WebSocket 端点是根路径 "/"（不是 /api/）
        var cleanBase = baseURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        if cleanBase.hasSuffix("/api") || cleanBase.hasSuffix("/api/") {
            cleanBase = String(cleanBase.dropLast(4)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let scheme = baseURL.hasPrefix("https") ? "wss" : "ws"
        relayURL = "\(scheme)://\(cleanBase)/"

        guard URL(string: relayURL) != nil else {
            errorMessage = "无效的 URL: \(relayURL)"
            currentState = .disconnected
            return
        }

        deviceToken = token
        performConnect()
    }

    func disconnect() {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard currentState != .disconnected else { return }
        currentState = .disconnected

        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        isReconnecting = false
        pingTask?.cancel()
        pingTask = nil
        unacknowledgedMessageIds.removeAll()
        pendingMessages.removeAll()

        disconnectInternal()
    }

    // MARK: - Connection Logic

    private func performConnect() {
        guard let url = URL(string: relayURL) else { return }

        print("[WSChat] Connecting to \(relayURL)")
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()

        // 先等 registered 再设 isConnected=true
        receiveMessage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendRegister()
        }

        // 注册超时保护
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if currentState == .connecting && !isConnected {
                print("[WSChat] Initial connect timeout, scheduling reconnect")
                handleConnectionFailure()
            }
        }
    }

    private func disconnectInternal() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Reconnection (Exponential Backoff)

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[WSChat] Max reconnect attempts reached, giving up")
            Task { @MainActor in
                self.errorMessage = "连接失败，请检查网络后重试"
                self.currentState = .disconnected
            }
            return
        }

        isReconnecting = true
        reconnectAttempts += 1

        // 指数退避：delay = min(base * 2^attempts + jitter, maxDelay)
        let delay = min(
            baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)),
            maxReconnectDelay
        )
        let jitter = Double.random(in: 0...0.5)
        let actualDelay = delay + jitter

        print("[WSChat] Scheduling reconnect #\(reconnectAttempts) in \(String(format: "%.1f", actualDelay))s (max: \(maxReconnectAttempts))")

        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.performReconnect()
            }
        }
    }

    private func performReconnect() {
        guard currentState == .reconnecting || currentState == .connecting else {
            print("[WSChat] performReconnect called but state is \(currentState), aborting")
            return
        }

        guard let url = URL(string: relayURL) else { return }

        print("[WSChat] Performing reconnect #\(reconnectAttempts) to \(relayURL)")

        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = false
        receiveMessage()

        // 重连超时保护
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !isConnected && currentState != .disconnected {
                print("[WSChat] Reconnect timeout, scheduling next attempt")
                handleConnectionFailure()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendRegister()
        }
    }

    private func handleConnectionFailure() {
        isReconnecting = false
        disconnectInternal()
        currentState = .reconnecting
        scheduleReconnect()
    }

    // MARK: - Heartbeat

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
                if error != nil {
                    print("[WSChat] Ping failed: \(error!.localizedDescription), scheduling reconnect")
                    self?.handleDisconnection()
                }
            }
        }
    }

    private func handleDisconnection() {
        isConnected = false

        // 记录未确认的消息 ID，用于重连后重发
        unacknowledgedMessageIds.formUnion(pendingMessages.keys)
        pendingMessages.removeAll()

        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        print("[WSChat] Disconnected, unacknowledged messages: \(self.unacknowledgedMessageIds.count)")

        if !isReconnecting {
            currentState = .reconnecting
            scheduleReconnect()
        }
    }

    // MARK: - Register

    private func sendRegister() {
        let msg: [String: Any] = [
            "type": "register",
            "token": deviceToken
        ]
        send(msg)
    }

    // MARK: - Send Chat Message

    func sendChatMessage(_ text: String, onResponse: @escaping (String?) -> Void) {
        // 重置流式内容状态
        lastAIResponse = nil
        hasStreamedContent = false

        let id = UUID().uuidString
        let content: [String: Any] = [
            "type": "req",
            "id": id,
            "method": "chat.send",
            "params": [
                "message": text,
                "deliver": false
            ]
        ]

        let wrapper: [String: Any] = [
            "type": "message",
            "content": JSONString(content)
        ]

        pendingMessages[id] = onResponse
        send(wrapper)
        print("[WSChat] Sent chat.send message, id=\(id)")
    }

    // MARK: - Stream Callback

    func setStreamCallback(_ callback: @escaping (String) -> Void) {
        streamCallback = callback
    }

    // MARK: - Low-level Send

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error = error {
                print("[WSChat] Send error: \(error)")
                Task { @MainActor in
                    self?.errorMessage = "发送失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Receive Loop

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task { @MainActor [weak self] in
                        self?.handleMessage(text)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor [weak self] in
                            self?.handleMessage(text)
                        }
                    }
                @unknown default:
                    break
                }
                Task { @MainActor [weak self] in
                    self?.receiveMessage()
                }

            case .failure(let error):
                print("[WSChat] Receive error: \(error)")
                Task { @MainActor [weak self] in
                    self?.handleDisconnection()
                }
            }
        }
    }

    // MARK: - Message Handler

    private func handleMessage(_ text: String) {
        print("[WSChat] Received: \(text.prefix(300))")

        guard let data = text.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let type = dict["type"] as? String ?? ""

        Task { @MainActor in
            switch type {
            case "registered":
                if let role = dict["role"] as? String, role == "device" {
                    print("[WSChat] Device registered successfully!")
                    self.isConnected = true
                    self.currentState = .connected
                    self.errorMessage = nil
                    self.reconnectAttempts = 0
                    self.isReconnecting = false
                    self.startHeartbeat()

                    // 重发未确认的消息
                    for id in self.unacknowledgedMessageIds {
                        print("[WSChat] Notifying to resend unacknowledged message: \(id)")
                        NotificationCenter.default.post(
                            name: .wsResendMessage,
                            object: id
                        )
                    }
                    self.unacknowledgedMessageIds.removeAll()
                }

            case "message":
                if let from = dict["from"] as? String, from == "gateway",
                   let contentStr = dict["content"] as? String {
                    self.handleGatewayMessage(contentStr)
                }

            case "error":
                let msg = dict["message"] as? String ?? "Unknown error"
                print("[WSChat] Error from relay: \(msg)")
                self.errorMessage = msg

            case "gateway_disconnected":
                self.handleDisconnection()

            default:
                print("[WSChat] Unknown message type: \(type)")
            }
        }
    }

    // MARK: - Gateway Message Handler

    private func handleGatewayMessage(_ contentStr: String) {
        guard let contentData = contentStr.data(using: .utf8),
              let content = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            return
        }

        let msgType = content["type"] as? String ?? ""
        print("[WSChat] handleGatewayMessage: type=\(msgType), content=\(contentStr.prefix(200))")

        switch msgType {
        case "res":
            if let id = content["id"] as? String,
               let callback = pendingMessages.removeValue(forKey: id) {
                unacknowledgedMessageIds.remove(id)
                let result = content["payload"] as? String ?? ""
                let error = content["error"] as? [String: Any]
                if hasStreamedContent && result.isEmpty {
                    hasStreamedContent = false
                } else {
                    callback(error == nil ? result : "错误: \(error?["message"] ?? "unknown")")
                }
            }

        case "event":
            if let event = content["event"] as? String {
                print("[WSChat] handleGatewayMessage: event=\(event), payload=\(content["payload"] ?? "nil")")

                if event == "chat" {
                    if let payload = content["payload"] as? [String: Any] {
                        var streamedText = ""

                        if let delta = payload["delta"] as? String {
                            streamCallback?(delta)
                            streamedText += delta
                            hasStreamedContent = true
                            lastAIResponse = (lastAIResponse ?? "") + delta
                        }

                        if let text = payload["text"] as? String {
                            if !text.isEmpty {
                                self.incomingMessages.append(text)
                            }
                            hasStreamedContent = true
                            lastAIResponse = (lastAIResponse ?? "") + text
                        }

                        if payload["state"] as? String == "final" {
                            if !hasStreamedContent {
                                let callbacks = Array(pendingMessages.values)
                                pendingMessages.removeAll()
                                for callback in callbacks {
                                    callback(streamedText.isEmpty ? "" : streamedText)
                                }
                            }
                            hasStreamedContent = false
                        }
                    }
                }

                if event == "agent" {
                    if let payload = content["payload"] as? [String: Any],
                       let stream = payload["stream"] as? String,
                       stream == "assistant",
                       let data = payload["data"] as? [String: Any],
                       let text = data["text"] as? String {
                        streamCallback?(text)
                        self.incomingMessages.append(text)
                        hasStreamedContent = true
                        lastAIResponse = (lastAIResponse ?? "") + text
                    }
                }
            }

        default:
            print("[WSChat] Unknown gateway message type: \(msgType)")
        }
    }

    // MARK: - Helpers

    private func JSONString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketChatService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {
        print("[WSChat] WebSocket did open")
    }

    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                                reason: Data?) {
        print("[WSChat] WebSocket closed with code: \(closeCode)")
        Task { @MainActor in
            self.handleDisconnection()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let wsResendMessage = Notification.Name("wsResendMessage")
}
