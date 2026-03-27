import Foundation

// ============================================
// MARK: - Agent
// ============================================

struct Agent: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var modelId: String
    var systemPrompt: String
    var status: AgentStatus
    var createdAt: Date
    var lastActiveAt: Date
    var conversationCount: Int
    var tags: [String]

    enum AgentStatus: String, Codable {
        case idle = "idle"
        case running = "running"
        case error = "error"
    }

    static let preview = Agent(
        id: "agent_001",
        name: "Data Analyzer",
        description: "数据分析助手",
        modelId: "model_001",
        systemPrompt: "你是一个专业的数据分析师...",
        status: .running,
        createdAt: Date(),
        lastActiveAt: Date().addingTimeInterval(-120),
        conversationCount: 342,
        tags: ["数据分析", "可视化"]
    )

    static let previewList: [Agent] = [
        Agent(id: "agent_001", name: "Data Analyzer", description: "数据分析助手", modelId: "model_001",
              systemPrompt: "", status: .running, createdAt: Date(), lastActiveAt: Date().addingTimeInterval(-120),
              conversationCount: 342, tags: ["数据分析"]),
        Agent(id: "agent_002", name: "Content Writer", description: "内容撰写助手", modelId: "model_002",
              systemPrompt: "", status: .idle, createdAt: Date().addingTimeInterval(-86400), lastActiveAt: Date().addingTimeInterval(-900),
              conversationCount: 156, tags: ["写作", "文案"]),
        Agent(id: "agent_003", name: "Code Reviewer", description: "代码审查助手", modelId: "model_001",
              systemPrompt: "", status: .idle, createdAt: Date().addingTimeInterval(-172800), lastActiveAt: Date().addingTimeInterval(-3600),
              conversationCount: 89, tags: ["代码", "审查"]),
        Agent(id: "agent_004", name: "Trade Advisor", description: "交易策略顾问", modelId: "model_003",
              systemPrompt: "", status: .running, createdAt: Date().addingTimeInterval(-259200), lastActiveAt: Date().addingTimeInterval(-60),
              conversationCount: 523, tags: ["交易", "策略"])
    ]
}

// ============================================
// MARK: - Conversation
// ============================================

struct Conversation: Identifiable, Codable {
    let id: String
    let agentId: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var tokenCount: Int

    struct Message: Identifiable, Codable {
        let id: String
        let role: MessageRole
        let content: String
        let timestamp: Date

        enum MessageRole: String, Codable {
            case user = "user"
            case assistant = "assistant"
            case system = "system"
        }
    }
}
