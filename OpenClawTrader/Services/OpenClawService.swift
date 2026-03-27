import Foundation

//
//  OpenClawService.swift
//  OpenClawTrader
//
//  功能：OpenClaw平台服务，管理Workspace/模型/Agent/工作流
//

// ============================================
// MARK: - OpenClaw Service
// ============================================

@MainActor
class OpenClawService: ObservableObject {
    static let shared = OpenClawService()

    @Published var workspaces: [Workspace] = []
    @Published var currentWorkspace: Workspace?
    @Published var models: [AIModel] = []
    @Published var agents: [Agent] = []
    @Published var workflows: [Workflow] = []

    @Published var isLoading = false
    @Published var error: String?

    private init() {
        loadMockData()
    }

    // MARK: - Mock Data

    private func loadMockData() {
        workspaces = [
            Workspace(id: "ws_001", name: "Production", description: "生产环境", createdAt: Date(), isActive: true,
                     agentCount: 12, workflowCount: 8, tokenUsage: Workspace.TokenUsage(total: 5000000, usedToday: 450000, limit: 5000000)),
            Workspace(id: "ws_002", name: "Development", description: "开发环境", createdAt: Date().addingTimeInterval(-86400), isActive: false,
                     agentCount: 5, workflowCount: 3, tokenUsage: Workspace.TokenUsage(total: 1000000, usedToday: 120000, limit: 1000000)),
            Workspace(id: "ws_003", name: "Testing", description: "测试环境", createdAt: Date().addingTimeInterval(-172800), isActive: false,
                     agentCount: 3, workflowCount: 2, tokenUsage: Workspace.TokenUsage(total: 500000, usedToday: 45000, limit: 500000))
        ]
        currentWorkspace = workspaces.first { $0.isActive } ?? workspaces.first

        models = AIModel.previewList
        agents = Agent.previewList
        workflows = Workflow.previewList
    }

    // MARK: - Workspace Operations

    /// 切换当前工作空间
    /// - Parameter workspace: 要切换的目标工作空间
    func switchWorkspace(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }

        for i in workspaces.indices {
            workspaces[i].isActive = (workspaces[i].id == workspace.id)
        }
        currentWorkspace = workspaces[index]
    }

    /// 创建新工作空间
    /// - Parameters:
    ///   - name: 工作空间名称
    ///   - description: 工作空间描述
    func createWorkspace(name: String, description: String) {
        let newWorkspace = Workspace(
            id: "ws_\(UUID().uuidString.prefix(8))",
            name: name,
            description: description,
            createdAt: Date(),
            isActive: false,
            agentCount: 0,
            workflowCount: 0,
            tokenUsage: Workspace.TokenUsage(total: 0, usedToday: 0, limit: 1000000)
        )
        workspaces.append(newWorkspace)
    }

    // MARK: - Model Operations

    /// 设置默认模型
    /// - Parameter model: 要设为默认的模型
    func setDefaultModel(_ model: AIModel) {
        for i in models.indices {
            models[i].isDefault = (models[i].id == model.id)
        }
    }

    /// 更新模型配置
    /// - Parameters:
    ///   - model: 要更新的模型
    ///   - config: 新的模型配置
    func updateModelConfig(_ model: AIModel, config: AIModel.ModelConfig) {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[index].config = config
    }

    // MARK: - Agent Operations

    /// 创建新 Agent
    /// - Parameters:
    ///   - name: Agent 名称
    ///   - description: Agent 描述
    ///   - modelId: 使用的模型 ID
    ///   - systemPrompt: 系统提示词
    func createAgent(name: String, description: String, modelId: String, systemPrompt: String) {
        let newAgent = Agent(
            id: "agent_\(UUID().uuidString.prefix(8))",
            name: name,
            description: description,
            modelId: modelId,
            systemPrompt: systemPrompt,
            status: .idle,
            createdAt: Date(),
            lastActiveAt: Date(),
            conversationCount: 0,
            tags: []
        )
        agents.append(newAgent)
    }

    /// 删除指定 Agent
    /// - Parameter agent: 要删除的 Agent
    func deleteAgent(_ agent: Agent) {
        agents.removeAll { $0.id == agent.id }
    }

    /// 启动指定 Agent
    /// - Parameter agent: 要启动的 Agent
    func startAgent(_ agent: Agent) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index].status = .running
        agents[index].lastActiveAt = Date()
    }

    /// 停止指定 Agent
    /// - Parameter agent: 要停止的 Agent
    func stopAgent(_ agent: Agent) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index].status = .idle
    }

    // MARK: - Workflow Operations

    /// 切换工作流状态（激活/暂停）
    /// - Parameter workflow: 要切换的工作流
    func toggleWorkflowStatus(_ workflow: Workflow) {
        guard let index = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        switch workflows[index].status {
        case .active:
            workflows[index].status = .paused
        case .paused:
            workflows[index].status = .active
        case .error, .draft:
            workflows[index].status = .active
        }
    }

    /// 手动运行工作流
    /// - Parameter workflow: 要运行的工作流
    func runWorkflow(_ workflow: Workflow) {
        guard let index = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        workflows[index].status = .active
        workflows[index].lastRunAt = Date()
        workflows[index].totalRuns += 1
    }
}
