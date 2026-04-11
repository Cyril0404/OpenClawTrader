import Foundation

//
//  APIClient.swift
//  OpenClawTrader
//
//  功能：OpenClaw API 网络请求客户端
//

// ============================================
// MARK: - API Client
// ============================================

actor APIClient {
    static let shared = APIClient()

    private var baseURL: String = ""
    private var apiKey: String = ""

    private init() {}

    // MARK: - Config

    func configure(baseURL: String, apiKey: String) {
        // 移除末尾的 /
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey
    }

    func clear() {
        baseURL = ""
        apiKey = ""
    }

    func isConfigured() -> Bool {
        !baseURL.isEmpty && !apiKey.isEmpty
    }

    // MARK: - Generic Request

    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod = .get, body: Encodable? = nil) async throws -> T {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw APIError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - API Methods

    /// 测试连接状态（HTTP 响应是裸 JSON，直接解析）
    func testConnection() async throws -> StatusResponse {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw APIError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/v1/status") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StatusResponse.self, from: data)
    }

    /// 发送聊天消息
    func sendChatMessage(_ message: String, agentId: String? = nil) async throws -> ChatResponse {
        let body = ChatRequest(message: message, agentId: agentId)
        return try await request("/v1/chat", method: .post, body: body)
    }

    /// 获取 Workspace 列表
    func getWorkspaces() async throws -> [WorkspaceResponse] {
        return try await request("/v1/workspaces", method: .get)
    }

    /// 获取 Agent 列表
    func getAgents() async throws -> [AgentResponse] {
        // TODO: 根据实际 API 端点调整
        return try await request("/v1/agents", method: .get)
    }

    /// 获取模型列表
    func getModels() async throws -> [ModelResponse] {
        // TODO: 根据实际 API 端点调整
        return try await request("/v1/models", method: .get)
    }

    /// 获取工作流列表
    func getWorkflows() async throws -> [WorkflowResponse] {
        // TODO: 根据实际 API 端点调整
        return try await request("/v1/workflows", method: .get)
    }

    // MARK: - HTTP Method

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    // MARK: - API Error

    enum APIError: Error, LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case decodingError(Error)
        case serverError(message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "API 未配置"
            case .invalidURL: return "无效的 URL"
            case .invalidResponse: return "无效的响应"
            case .httpError(let statusCode): return "HTTP 错误: \(statusCode)"
            case .decodingError(let error): return "解码错误: \(error.localizedDescription)"
            case .serverError(let message): return "服务器错误: \(message)"
            }
        }
    }
}

// ============================================
// MARK: - API Models
// ============================================

// JSON-RPC 2.0 响应包装器（Gateway API 所有响应都包在这一层）
struct JSONRPCResponse<T: Codable>: Codable {
    let type: String       // "res"
    let id: String?
    let ok: Bool?
    let error: JSONRPCError?
    let payload: T?         // 实际数据在这里

    struct JSONRPCError: Codable {
        let code: Int?
        let message: String?
    }
}

struct StatusResponse: Codable {
    let runtimeVersion: String?
    let heartbeat: HeartbeatInfo?
    let sessions: SessionsInfo?

    struct SessionsInfo: Codable {
        let defaults: SessionDefaults?

        struct SessionDefaults: Codable {
            let model: String?
            let contextTokens: Int?
        }
    }

    struct HeartbeatInfo: Codable {
        let defaultAgentId: String?
        let agents: [AgentInfo]?
        let channelSummary: [String: ChannelInfo]?

        enum CodingKeys: String, CodingKey {
            case defaultAgentId = "defaultAgentId"
            case agents
            case channelSummary
        }
    }

    struct AgentInfo: Codable {
        let agentId: String?
        let enabled: Bool?
        let every: String?

        enum CodingKeys: String, CodingKey {
            case agentId = "agentId"
            case enabled
            case every
        }
    }

    struct ChannelInfo: Codable {
        let configured: Bool?
        let running: Bool?
    }

    enum CodingKeys: String, CodingKey {
        case runtimeVersion
        case heartbeat
        case sessions
    }
}

struct ChatRequest: Encodable {
    let message: String
    let agentId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case agentId = "agent_id"
    }
}

struct ChatResponse: Decodable {
    let id: String?
    let message: String?
    let agentId: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case agentId = "agent_id"
        case createdAt = "created_at"
    }
}

struct WorkspaceResponse: Codable {
    let id: String
    let name: String
    let description: String?
    let createdAt: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

// MARK: - Agent Response

struct AgentResponse: Codable {
    let id: String
    let name: String?
    let description: String?
    let modelId: String?
    let status: String?
    let createdAt: String?
    let lastActiveAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case modelId = "model_id"
        case status
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
    }
}

// MARK: - Model Response

struct ModelResponse: Codable {
    let id: String
    let name: String
    let provider: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case provider
        case status
    }
}

// MARK: - Workflow Response

struct WorkflowResponse: Codable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case createdAt = "created_at"
    }
}
