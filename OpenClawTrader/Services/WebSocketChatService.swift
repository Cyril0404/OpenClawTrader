import Foundation

// ============================================================
// WebSocketChatService — 通过 relay-server WebSocket 收发聊天消息
//
// 协议：
//   1. 连接成功后发送 { type: "register", token: "<pairingToken>" }
//   2. 收到 { type: "registered", role: "device" } → 注册成功
//   3. 发消息: { type: "message", content: "{\"type\":\"req\",\"id\":\"...\",\"method\":\"chat\",\"params\":{\"message\":\"...\"}}" }
//   4. 收消息: { type: "message", from: "gateway", content: "..." } → 解析 content
// ============================================================

@MainActor
class WebSocketChatService: NSObject, ObservableObject {
    static let shared = WebSocketChatService()

    @Published var isConnected = false
    @Published var lastAIResponse: String?
    @Published var errorMessage: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var relayURL: String = ""
    private var deviceToken: String = ""
    private var pendingMessages: [String: (String?) -> Void] = [:]
    private var streamCallback: ((String) -> Void)?

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
        relayURL = "ws://\(cleanBase)/"

        guard let url = URL(string: relayURL) else {
            errorMessage = "无效的 URL: \(relayURL)"
            return
        }

        deviceToken = token
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()

        print("[WSChat] Connecting to \(relayURL) with token \(token.prefix(8))...")

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
        let id = UUID().uuidString
        let content: [String: Any] = [
            "type": "req",
            "id": id,
            "method": "chat",
            "params": [
                "message": text
            ]
        ]

        let wrapper: [String: Any] = [
            "type": "message",
            "content": JSONString(content)
        ]

        pendingMessages[id] = onResponse
        send(wrapper)
        print("[WSChat] Sent chat message, id=\(id)")
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

        switch msgType {
        case "res":
            if let id = content["id"] as? String,
               let callback = pendingMessages.removeValue(forKey: id) {
                let result = content["payload"] as? String ?? ""
                let error = content["error"] as? [String: Any]
                callback(error == nil ? result : "错误: \(error?["message"] ?? "unknown")")
            }

        case "event":
            if let event = content["event"] as? String {
                // 处理聊天事件
                if event == "chat_start" || event == "chat_fragment" || event == "chat_end" {
                    if let payload = content["payload"] as? [String: Any],
                       let text = payload["text"] as? String {
                        streamCallback?(text)
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
