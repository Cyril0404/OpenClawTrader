import Foundation

// ============================================
// MARK: - Workflow
// ============================================

struct Workflow: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var status: WorkflowStatus
    var triggerType: TriggerType
    var lastRunAt: Date?
    var totalRuns: Int
    var failedRuns: Int
    var avgDuration: Double
    var steps: [WorkflowStep]

    enum WorkflowStatus: String, Codable {
        case active = "active"
        case paused = "paused"
        case error = "error"
        case draft = "draft"
    }

    enum TriggerType: String, Codable {
        case manual = "manual"
        case scheduled = "scheduled"
        case event = "event"
        case webhook = "webhook"
    }

    static let preview = Workflow(
        id: "wf_001",
        name: "每日报告生成",
        description: "自动生成并发送每日运营报告",
        status: .active,
        triggerType: .scheduled,
        lastRunAt: Date().addingTimeInterval(-3600),
        totalRuns: 156,
        failedRuns: 3,
        avgDuration: 45.5,
        steps: [
            WorkflowStep(id: "step_001", name: "收集数据", type: "data_fetch", status: .completed),
            WorkflowStep(id: "step_002", name: "分析处理", type: "process", status: .completed),
            WorkflowStep(id: "step_003", name: "生成报告", type: "generate", status: .running),
            WorkflowStep(id: "step_004", name: "发送通知", type: "notify", status: .pending)
        ]
    )

    static let previewList: [Workflow] = [
        Workflow(id: "wf_001", name: "每日报告生成", description: "自动生成并发送每日运营报告", status: .active, triggerType: .scheduled,
                 lastRunAt: Date().addingTimeInterval(-3600), totalRuns: 156, failedRuns: 3, avgDuration: 45.5, steps: []),
        Workflow(id: "wf_002", name: "客户持仓分析", description: "分析客户持仓并生成建议", status: .active, triggerType: .webhook,
                 lastRunAt: Date().addingTimeInterval(-7200), totalRuns: 89, failedRuns: 1, avgDuration: 12.3, steps: []),
        Workflow(id: "wf_003", name: "交易信号监控", description: "实时监控交易信号", status: .paused, triggerType: .event,
                 lastRunAt: Date().addingTimeInterval(-86400), totalRuns: 234, failedRuns: 12, avgDuration: 2.1, steps: []),
        Workflow(id: "wf_004", name: "模型批量处理", description: "批量处理数据并调用模型", status: .error, triggerType: .scheduled,
                 lastRunAt: Date().addingTimeInterval(-1800), totalRuns: 45, failedRuns: 8, avgDuration: 120.0, steps: [])
    ]
}

// ============================================
// MARK: - Workflow Step
// ============================================

struct WorkflowStep: Identifiable, Codable {
    let id: String
    var name: String
    var type: String
    var status: StepStatus

    enum StepStatus: String, Codable {
        case pending = "pending"
        case running = "running"
        case completed = "completed"
        case failed = "failed"
        case skipped = "skipped"
    }
}

// ============================================
// MARK: - Workflow Log
// ============================================

struct WorkflowLog: Identifiable, Codable {
    let id: String
    let workflowId: String
    let stepId: String
    let level: LogLevel
    let message: String
    let timestamp: Date

    enum LogLevel: String, Codable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
    }
}
