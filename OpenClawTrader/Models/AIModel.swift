import Foundation

// ============================================
// MARK: - AI Model
// ============================================

struct AIModel: Identifiable, Codable {
    let id: String
    var name: String
    var provider: String
    var version: String
    var status: ModelStatus
    var isDefault: Bool
    var config: ModelConfig
    var usageStats: UsageStats

    enum ModelStatus: String, Codable {
        case active = "active"
        case idle = "idle"
        case error = "error"
    }

    struct ModelConfig: Codable {
        var temperature: Double
        var maxTokens: Int
        var topP: Double
        var frequencyPenalty: Double
        var presencePenalty: Double
    }

    struct UsageStats: Codable {
        var totalCalls: Int
        var totalTokens: Int
        var successfulCalls: Int
        var failedCalls: Int
        var avgResponseTime: Double
    }

    static let preview = AIModel(
        id: "model_001",
        name: "GPT-4 Turbo",
        provider: "OpenAI",
        version: "2024-04-09",
        status: .active,
        isDefault: true,
        config: ModelConfig(
            temperature: 0.7,
            maxTokens: 4096,
            topP: 1.0,
            frequencyPenalty: 0.0,
            presencePenalty: 0.0
        ),
        usageStats: UsageStats(
            totalCalls: 15420,
            totalTokens: 125000000,
            successfulCalls: 15380,
            failedCalls: 40,
            avgResponseTime: 1.2
        )
    )

    static let previewList: [AIModel] = [
        AIModel(id: "model_001", name: "GPT-4 Turbo", provider: "OpenAI", version: "2024-04-09", status: .active, isDefault: true,
                config: ModelConfig(temperature: 0.7, maxTokens: 4096, topP: 1.0, frequencyPenalty: 0.0, presencePenalty: 0.0),
                usageStats: UsageStats(totalCalls: 15420, totalTokens: 125000000, successfulCalls: 15380, failedCalls: 40, avgResponseTime: 1.2)),
        AIModel(id: "model_002", name: "Claude 3 Opus", provider: "Anthropic", version: "3.0", status: .idle, isDefault: false,
                config: ModelConfig(temperature: 0.8, maxTokens: 4096, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
                usageStats: UsageStats(totalCalls: 8200, totalTokens: 68000000, successfulCalls: 8180, failedCalls: 20, avgResponseTime: 1.5)),
        AIModel(id: "model_003", name: "Gemini Pro 1.5", provider: "Google", version: "1.5", status: .idle, isDefault: false,
                config: ModelConfig(temperature: 0.6, maxTokens: 8192, topP: 0.95, frequencyPenalty: 0.0, presencePenalty: 0.0),
                usageStats: UsageStats(totalCalls: 5600, totalTokens: 45000000, successfulCalls: 5590, failedCalls: 10, avgResponseTime: 0.9))
    ]
}
