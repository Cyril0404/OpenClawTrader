import Foundation

//
//  Notification.swift
//  OpenClawTrader
//
//  功能：通知数据模型，支持多类型通知
//

// ============================================
// MARK: - App Notification
// ============================================

struct AppNotification: Identifiable, Codable {
    let id: String
    var type: NotificationType
    var title: String
    var body: String
    var timestamp: Date
    var isRead: Bool
    var actionData: String?

    enum NotificationType: String, Codable {
        case agent = "agent"
        case workflow = "workflow"
        case trade = "trade"
        case price = "price"
        case system = "system"
    }

    var icon: String {
        switch type {
        case .agent: return "cpu"
        case .workflow: return "arrow.triangle.branch"
        case .trade: return "chart.line.uptrend.xyaxis"
        case .price: return "bell.badge"
        case .system: return "gearshape"
        }
    }

    var iconColor: String {
        switch type {
        case .agent: return "3498DB"
        case .workflow: return "F39C12"
        case .trade: return "2ECC71"
        case .price: return "E74C3C"
        case .system: return "8A8A8A"
        }
    }

    static let preview = AppNotification(
        id: "notif_001",
        type: .agent,
        title: "Agent 执行完成",
        body: "Data Analyzer 已完成处理 156 条数据",
        timestamp: Date(),
        isRead: false,
        actionData: "agent_001"
    )

    static let previewList: [AppNotification] = [
        AppNotification(id: "notif_001", type: .agent, title: "Agent 执行完成", body: "Data Analyzer 已完成处理 156 条数据",
                        timestamp: Date(), isRead: false, actionData: "agent_001"),
        AppNotification(id: "notif_002", type: .workflow, title: "工作流异常", body: "模型批量处理工作流执行失败",
                        timestamp: Date().addingTimeInterval(-1800), isRead: false, actionData: "wf_004"),
        AppNotification(id: "notif_003", type: .trade, title: "交易建议采纳", body: "您已采纳 AI 建议，调整了 AAPL 仓位",
                        timestamp: Date().addingTimeInterval(-3600), isRead: true, actionData: nil),
        AppNotification(id: "notif_004", type: .price, title: "价格预警", body: "NVDA 上涨超过 5%，当前涨幅 5.8%",
                        timestamp: Date().addingTimeInterval(-7200), isRead: true, actionData: "NVDA"),
        AppNotification(id: "notif_005", type: .system, title: "Token 使用提醒", body: "本月已使用 80% 的 Token 配额",
                        timestamp: Date().addingTimeInterval(-86400), isRead: true, actionData: nil)
    ]
}
