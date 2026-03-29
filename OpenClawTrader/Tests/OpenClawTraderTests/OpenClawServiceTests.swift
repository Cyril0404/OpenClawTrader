import XCTest
@testable import OpenClawTrader

@MainActor
final class OpenClawServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StorageService.shared.disconnect()
        StorageService.shared.clearUser()
        OpenClawService.shared.reset()
    }

    override func tearDown() {
        OpenClawService.shared.reset()
        StorageService.shared.disconnect()
        StorageService.shared.clearUser()
        super.tearDown()
    }

    // MARK: - Reset Tests

    func testResetClearsAllData() {
        // 设置一些数据
        OpenClawService.shared.workspaces = [
            Workspace(id: "1", name: "Test", description: "", createdAt: Date(), isActive: true, agentCount: 1, workflowCount: 0, tokenUsage: Workspace.TokenUsage(total: 100, usedToday: 10, limit: 100))
        ]
        let defaultConfig = AIModel.ModelConfig(temperature: 0.7, maxTokens: 2048, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
        let defaultUsageStats = AIModel.UsageStats(totalCalls: 0, totalTokens: 0, successfulCalls: 0, failedCalls: 0, avgResponseTime: 0)
        OpenClawService.shared.models = [
            AIModel(id: "1", name: "GPT-4", provider: "OpenAI", version: "1.0", status: .active, isDefault: true, config: defaultConfig, usageStats: defaultUsageStats)
        ]
        OpenClawService.shared.agents = [
            Agent(id: "1", name: "TestAgent", description: "", modelId: "1", systemPrompt: "", status: .running, createdAt: Date(), lastActiveAt: Date(), conversationCount: 5, tags: [])
        ]

        // Reset
        OpenClawService.shared.reset()

        XCTAssertTrue(OpenClawService.shared.workspaces.isEmpty)
        XCTAssertTrue(OpenClawService.shared.models.isEmpty)
        XCTAssertTrue(OpenClawService.shared.agents.isEmpty)
        XCTAssertTrue(OpenClawService.shared.workflows.isEmpty)
        XCTAssertNil(OpenClawService.shared.currentWorkspace)
        XCTAssertNil(OpenClawService.shared.mainAgent)
        XCTAssertNil(OpenClawService.shared.error)
    }

    // MARK: - Workspace Operations

    func testSwitchWorkspace() {
        let ws1 = Workspace(id: "1", name: "Workspace 1", description: "", createdAt: Date(), isActive: false, agentCount: 0, workflowCount: 0, tokenUsage: .init(total: 0, usedToday: 0, limit: 0))
        let ws2 = Workspace(id: "2", name: "Workspace 2", description: "", createdAt: Date(), isActive: false, agentCount: 0, workflowCount: 0, tokenUsage: .init(total: 0, usedToday: 0, limit: 0))

        OpenClawService.shared.workspaces = [ws1, ws2]

        OpenClawService.shared.switchWorkspace(ws2)

        XCTAssertEqual(OpenClawService.shared.currentWorkspace?.id, "2")
        XCTAssertTrue(OpenClawService.shared.workspaces.first { $0.id == "2" }?.isActive ?? false)
        XCTAssertFalse(OpenClawService.shared.workspaces.first { $0.id == "1" }?.isActive ?? true)
    }

    func testCreateWorkspace() {
        let initialCount = OpenClawService.shared.workspaces.count

        OpenClawService.shared.createWorkspace(name: "New Workspace", description: "Test description")

        XCTAssertEqual(OpenClawService.shared.workspaces.count, initialCount + 1)
        XCTAssertEqual(OpenClawService.shared.workspaces.last?.name, "New Workspace")
        XCTAssertEqual(OpenClawService.shared.workspaces.last?.description, "Test description")
    }

    // MARK: - Model Operations

    func testSetDefaultModel() {
        let defaultConfig = AIModel.ModelConfig(temperature: 0.7, maxTokens: 2048, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
        let defaultUsageStats = AIModel.UsageStats(totalCalls: 0, totalTokens: 0, successfulCalls: 0, failedCalls: 0, avgResponseTime: 0)
        let model1 = AIModel(id: "1", name: "GPT-4", provider: "OpenAI", version: "1.0", status: .active, isDefault: false, config: defaultConfig, usageStats: defaultUsageStats)
        let model2 = AIModel(id: "2", name: "Claude", provider: "Anthropic", version: "1.0", status: .active, isDefault: false, config: defaultConfig, usageStats: defaultUsageStats)

        OpenClawService.shared.models = [model1, model2]

        OpenClawService.shared.setDefaultModel(model2)

        XCTAssertFalse(OpenClawService.shared.models.first { $0.id == "1" }?.isDefault ?? true)
        XCTAssertTrue(OpenClawService.shared.models.first { $0.id == "2" }?.isDefault ?? false)
    }

    func testUpdateModelConfig() {
        let defaultConfig = AIModel.ModelConfig(temperature: 0.7, maxTokens: 2048, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0)
        let defaultUsageStats = AIModel.UsageStats(totalCalls: 0, totalTokens: 0, successfulCalls: 0, failedCalls: 0, avgResponseTime: 0)
        let model = AIModel(id: "1", name: "GPT-4", provider: "OpenAI", version: "1.0", status: .active, isDefault: false, config: defaultConfig, usageStats: defaultUsageStats)
        OpenClawService.shared.models = [model]

        let newConfig = AIModel.ModelConfig(temperature: 0.9, maxTokens: 4096, topP: 0.95, frequencyPenalty: 0.5, presencePenalty: 0.5)
        OpenClawService.shared.updateModelConfig(model, config: newConfig)

        XCTAssertEqual(OpenClawService.shared.models.first?.config.temperature, 0.9)
        XCTAssertEqual(OpenClawService.shared.models.first?.config.maxTokens, 4096)
    }

    // MARK: - Agent Operations

    func testCreateAgent() {
        let initialCount = OpenClawService.shared.agents.count

        OpenClawService.shared.createAgent(name: "New Agent", description: "Test agent", modelId: "model-1", systemPrompt: "You are helpful")

        XCTAssertEqual(OpenClawService.shared.agents.count, initialCount + 1)
        XCTAssertEqual(OpenClawService.shared.agents.last?.name, "New Agent")
        XCTAssertEqual(OpenClawService.shared.agents.last?.status, .idle)
    }

    func testDeleteAgent() {
        let agent = Agent(id: "agent-1", name: "Test Agent", description: "", modelId: "1", systemPrompt: "", status: .idle, createdAt: Date(), lastActiveAt: Date(), conversationCount: 0, tags: [])
        OpenClawService.shared.agents = [agent]

        OpenClawService.shared.deleteAgent(agent)

        XCTAssertTrue(OpenClawService.shared.agents.isEmpty)
    }

    func testStartAgent() {
        let agent = Agent(id: "agent-1", name: "Test Agent", description: "", modelId: "1", systemPrompt: "", status: .idle, createdAt: Date(), lastActiveAt: Date(), conversationCount: 0, tags: [])
        OpenClawService.shared.agents = [agent]

        OpenClawService.shared.startAgent(agent)

        XCTAssertEqual(OpenClawService.shared.agents.first?.status, .running)
    }

    func testStopAgent() {
        let agent = Agent(id: "agent-1", name: "Test Agent", description: "", modelId: "1", systemPrompt: "", status: .running, createdAt: Date(), lastActiveAt: Date(), conversationCount: 0, tags: [])
        OpenClawService.shared.agents = [agent]

        OpenClawService.shared.stopAgent(agent)

        XCTAssertEqual(OpenClawService.shared.agents.first?.status, .idle)
    }

    // MARK: - Workflow Operations

    func testToggleWorkflowStatusActiveToPaused() {
        let workflow = Workflow(id: "1", name: "Test", description: "", status: .active, triggerType: .manual, lastRunAt: nil, totalRuns: 0, failedRuns: 0, avgDuration: 0, steps: [])
        OpenClawService.shared.workflows = [workflow]

        OpenClawService.shared.toggleWorkflowStatus(workflow)

        XCTAssertEqual(OpenClawService.shared.workflows.first?.status, .paused)
    }

    func testToggleWorkflowStatusPausedToActive() {
        let workflow = Workflow(id: "1", name: "Test", description: "", status: .paused, triggerType: .manual, lastRunAt: nil, totalRuns: 0, failedRuns: 0, avgDuration: 0, steps: [])
        OpenClawService.shared.workflows = [workflow]

        OpenClawService.shared.toggleWorkflowStatus(workflow)

        XCTAssertEqual(OpenClawService.shared.workflows.first?.status, .active)
    }

    func testRunWorkflow() {
        let workflow = Workflow(id: "1", name: "Test", description: "", status: .draft, triggerType: .manual, lastRunAt: nil, totalRuns: 0, failedRuns: 0, avgDuration: 0, steps: [])
        OpenClawService.shared.workflows = [workflow]

        OpenClawService.shared.runWorkflow(workflow)

        XCTAssertEqual(OpenClawService.shared.workflows.first?.status, .active)
        XCTAssertEqual(OpenClawService.shared.workflows.first?.totalRuns, 1)
        XCTAssertNotNil(OpenClawService.shared.workflows.first?.lastRunAt)
    }

    // MARK: - Conversations

    func testGetConversationForNewAgent() {
        let conversation = OpenClawService.shared.getConversation(for: "new-agent")
        XCTAssertTrue(conversation.isEmpty)
    }

    func testConversationPersistence() {
        let agentId = "test-agent"

        // 初始为空
        XCTAssertTrue(OpenClawService.shared.getConversation(for: agentId).isEmpty)

        // 模拟发送消息（直接操作 conversations）
        let message = Conversation.Message(id: "1", role: .user, content: "Hello", timestamp: Date())
        if OpenClawService.shared.conversations[agentId] == nil {
            OpenClawService.shared.conversations[agentId] = []
        }
        OpenClawService.shared.conversations[agentId]?.append(message)

        // 验证消息已保存
        let conversation = OpenClawService.shared.getConversation(for: agentId)
        XCTAssertEqual(conversation.count, 1)
        XCTAssertEqual(conversation.first?.content, "Hello")
    }
}
