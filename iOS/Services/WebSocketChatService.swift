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
// ============================================================

@MainActor
class WebSocketChatService: NSObject, ObservableObject {
    static let shared = WebSocketChatService()

    @Published var isConnected = false
    @Published var lastAIResponse: String?
    @Published var errorMessage: String?
    @Published var incomingMessages: [String] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var relayURL: String = ""
    private var deviceToken: String = ""
    private var pendingMessages: [String: (String?) -> Void] = [:]
    private var streamCallback: ((String) -> Void)?
    // 追踪是否已经有流式内容到达，避免 state==final 回调覆盖已 streaming 的内容
    private var hasStreamedContent = false

    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
    }

    // MARK: - 连接

    func connect(baseURL: String, token: String) {
        disconnect()

        // baseURL 格式是 "http://150.158.119.114:3001/api"
        // relay-server WebSocket 端点是根路径 "/"（不是 /api/）
        var cleanBase = baseURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        // 去掉末尾的 /api 或 /api/
        if cleanBase.hasSuffix("/api") || cleanBase.hasSuffix("/api/") {
            cleanBase = String(cleanBase.dropLast(4)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        // 根据 baseURL 协议决定使用 ws:// 还是 wss://
        let scheme = baseURL.hasPrefix("https") ? "wss" : "ws"
        relayURL = "\(scheme)://\(cleanBase)/"

        guard let url = URL(string: relayURL) else {
            errorMessage = "无效的 URL: \(relayURL)"
            return
        }

        deviceToken = token
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()

        print("[WSChat] Connecting to \(relayURL)")

        receiveMessage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendRegister()
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - 注册

    private func sendRegister() {
        let msg: [String: Any] = [
            "type": "register",
            "token": deviceToken
        ]
        send(msg)
    }

    // MARK: - 发消息

    func sendChatMessage(_ text: String, onResponse: @escaping (String?) -> Void) {
        // 重置流式内容状态
        lastAIResponse = nil
        hasStreamedContent = false

        let id = UUID().uuidString
        // 使用 chat.send 方法，deliver=false 让响应通过 WebSocket 事件推送
        let content: [String: Any] = [
            "type": "req",
            "id": id,
            "method": "chat.send",
            "params": [
                "message": text,
                "deliver": false  // 关键：让 Gateway 通过 WebSocket 推送响应
            ]
        ]

        let wrapper: [String: Any] = [
            "type": "message",
            "content": JSONString(content)
        ]

        // chat.send 不等待 RPC 响应，响应通过事件推送
        pendingMessages[id] = onResponse
        send(wrapper)
        print("[WSChat] Sent chat.send message, id=\(id)")
    }

    // MARK: - 事件监听

    func setStreamCallback(_ callback: @escaping (String) -> Void) {
        streamCallback = callback
    }

    // MARK: - 底层

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

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()

            case .failure(let error):
                print("[WSChat] Receive error: \(error)")
                Task { @MainActor in
                    self?.isConnected = false
                    self?.errorMessage = "连接断开: \(error.localizedDescription)"
                }
            }
        }
    }

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
                    self.errorMessage = nil
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
                self.isConnected = false
                self.errorMessage = "Gateway 断开了"

            default:
                print("[WSChat] Unknown message type: \(type)")
            }
        }
    }

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
                let result = content["payload"] as? String ?? ""
                let error = content["error"] as? [String: Any]
                // 如果已经有流式内容，不要用空结果覆盖
                if hasStreamedContent && result.isEmpty {
                    // 流式内容已通过 chat 事件处理，这里忽略空响应
                    hasStreamedContent = false
                } else {
                    callback(error == nil ? result : "错误: \(error?["message"] ?? "unknown")")
                }
            }

        case "event":
            if let event = content["event"] as? String {
                print("[WSChat] handleGatewayMessage: event=\(event), payload=\(content["payload"] ?? "nil")")
                // 处理 chat.push 事件（ClawPilot 协议）
                if event == "chat" {
                    if let payload = content["payload"] as? [String: Any] {
                        print("[WSChat] chat event payload: \(payload)")
                        var streamedText = ""
                        // chat.push 包含 delta 或 text
                        if let delta = payload["delta"] as? String {
                            print("[WSChat] chat delta: \(delta.prefix(100))")
                            streamCallback?(delta)
                            streamedText += delta
                            hasStreamedContent = true
                            lastAIResponse = (lastAIResponse ?? "") + delta
                        }
                        if let text = payload["text"] as? String {
                            print("[WSChat] chat text: \(text.prefix(100))")
                            // text 可能是完整内容或增量，先添加到 incomingMessages 显示
                            if !text.isEmpty {
                                self.incomingMessages.append(text)
                            }
                            hasStreamedContent = true
                            lastAIResponse = (lastAIResponse ?? "") + text
                        }
                        // state == "final" 表示聊天结束
                        if payload["state"] as? String == "final" {
                            // 如果已经有流式内容到达，不要用空内容覆盖回调
                            if hasStreamedContent {
                                // 标记流式内容已处理完毕，清除标志
                                hasStreamedContent = false
                            } else {
                                // 没有流式内容，调用回调处理（处理非 streaming 响应）
                                let callbacks = Array(pendingMessages.values)
                                pendingMessages.removeAll()
                                for callback in callbacks {
                                    callback(streamedText.isEmpty ? "" : streamedText)
                                }
                            }
                        }
                    }
                }
                // 处理 agent 事件（如 stream: "assistant"）
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

    private func JSONString(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
