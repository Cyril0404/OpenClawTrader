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
    @Published var mainAgent: Agent?

    @Published var isLoading = false
    @Published var error: String?
    @Published var isConnected = false

    private init() {
        // 如果有保存的配置，则加载
        if !StorageService.shared.apiBaseURL.isEmpty {
            Task {
                await connect()
            }
        }
    }

    private func setupMainAgent() {
        mainAgent = agents.first { $0.status == .running } ?? agents.first
    }

    // MARK: - Connection

    /// 连接到 OpenClaw API
    func connect() async {
        isLoading = true
        error = nil

        // 配置 APIClient
        let baseURL = StorageService.shared.apiBaseURL
        let apiKey = StorageService.shared.apiKey
        await APIClient.shared.configure(baseURL: baseURL, apiKey: apiKey)

        do {
            // 测试连接
            let status: StatusResponse = try await APIClient.shared.testConnection()
            print("OpenClaw Status: \(status.status ?? "unknown")")

            // 加载数据
            await loadFromAPI()

            isConnected = true
            StorageService.shared.isConnected = true
        } catch {
            self.error = error.localizedDescription
            isConnected = false
            StorageService.shared.isConnected = false
        }

        isLoading = false
    }

    /// 断开连接
    func disconnect() {
        Task {
            await APIClient.shared.clear()
        }
        StorageService.shared.disconnect()
        isConnected = false
        reset()
    }

    /// 触发重新连接（用于配对后立即连接）
    func triggerConnect() {
        Task {
            await connect()
        }
    }

    /// 从 API 加载数据
    func loadFromAPI() async {
        // 获取 workspaces
        do {
            let workspaceResponses: [WorkspaceResponse] = try await APIClient.shared.getWorkspaces()
            workspaces = workspaceResponses.map { response in
                Workspace(
                    id: response.id,
                    name: response.name,
                    description: response.description ?? "",
                    createdAt: ISO8601DateFormatter().date(from: response.createdAt ?? "") ?? Date(),
                    isActive: response.isActive ?? false,
                    agentCount: 0,
                    workflowCount: 0,
                    tokenUsage: Workspace.TokenUsage(total: 0, usedToday: 0, limit: 0)
                )
            }
            currentWorkspace = workspaces.first { $0.isActive } ?? workspaces.first
        } catch {
            print("获取 workspaces 失败: \(error.localizedDescription)")
        }

        // 获取 agents - 独立处理，失败不影响其他
        do {
            let agentResponses: [AgentResponse] = try await APIClient.shared.getAgents()
            agents = agentResponses.map { response in
                Agent(
                    id: response.id,
                    name: response.name,
                    description: response.description ?? "",
                    modelId: response.modelId ?? "",
                    systemPrompt: "",
                    status: Agent.AgentStatus(rawValue: response.status ?? "idle") ?? .idle,
                    createdAt: ISO8601DateFormatter().date(from: response.createdAt ?? "") ?? Date(),
                    lastActiveAt: ISO8601DateFormatter().date(from: response.lastActiveAt ?? "") ?? Date(),
                    conversationCount: 0,
                    tags: []
                )
            }
        } catch {
            print("获取 agents 失败: \(error.localizedDescription)")
        }

        // 获取 models - 独立处理
        do {
            let modelResponses: [ModelResponse] = try await APIClient.shared.getModels()
            models = modelResponses.map { response in
                AIModel(
                    id: response.id,
                    name: response.name,
                    provider: response.provider ?? "",
                    version: "1.0",
                    status: AIModel.ModelStatus(rawValue: response.status ?? "active") ?? .active,
                    isDefault: false,
                    config: AIModel.ModelConfig(temperature: 0.7, maxTokens: 2048, topP: 0.9, frequencyPenalty: 0.0, presencePenalty: 0.0),
                    usageStats: AIModel.UsageStats(totalCalls: 0, totalTokens: 0, successfulCalls: 0, failedCalls: 0, avgResponseTime: 0)
                )
            }
        } catch {
            print("获取 models 失败: \(error.localizedDescription)")
        }

        // 获取 workflows - 独立处理
        do {
            let workflowResponses: [WorkflowResponse] = try await APIClient.shared.getWorkflows()
            workflows = workflowResponses.map { response in
                Workflow(
                    id: response.id,
                    name: response.name,
                    description: response.description ?? "",
                    status: Workflow.WorkflowStatus(rawValue: response.status ?? "draft") ?? .draft,
                    triggerType: .manual,
                    lastRunAt: nil,
                    totalRuns: 0,
                    failedRuns: 0,
                    avgDuration: 0,
                    steps: []
                )
            }
        } catch {
            print("获取 workflows 失败: \(error.localizedDescription)")
        }

        setupMainAgent()
    }

    /// 测试连接（用于 OpenClawConnectView）
    static func testConnection(baseURL: String, apiKey: String) async throws -> StatusResponse {
        await APIClient.shared.configure(baseURL: baseURL, apiKey: apiKey)
        return try await APIClient.shared.testConnection()
    }

    // MARK: - Reset

    func reset() {
        workspaces = []
        currentWorkspace = nil
        models = []
        agents = []
        workflows = []
        mainAgent = nil
        error = nil
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

    // MARK: - Chat Operations

    @Published var conversations: [String: [Conversation.Message]] = [:] // agentId -> messages

    /// 发送消息给指定 Agent
    /// - Parameters:
    ///   - content: 消息内容
    ///   - agentId: Agent ID
    ///   - completion: 回调，返回 AI 回复
    func sendMessage(content: String, to agentId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 添加用户消息到会话历史
        let userMessage = Conversation.Message(
            id: UUID().uuidString,
            role: .user,
            content: content,
            timestamp: Date()
        )

        if conversations[agentId] == nil {
            conversations[agentId] = []
        }
        conversations[agentId]?.append(userMessage)

        // 调用 OpenClaw API
        Task {
            do {
                let response = try await APIClient.shared.sendChatMessage(content, agentId: agentId)

                // 添加 AI 回复到会话历史
                let replyContent = response.message ?? "收到消息"
                let assistantMessage = Conversation.Message(
                    id: response.id ?? UUID().uuidString,
                    role: .assistant,
                    content: replyContent,
                    timestamp: Date()
                )
                conversations[agentId]?.append(assistantMessage)

                await MainActor.run {
                    completion(.success(replyContent))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 获取当前 Agent 的会话历史
    func getConversation(for agentId: String) -> [Conversation.Message] {
        return conversations[agentId] ?? []
    }
}
