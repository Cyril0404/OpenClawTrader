import Foundation

//
//  Workspace.swift
//  OpenClawTrader
//
//  功能：Workspace数据模型
//

// ============================================
// MARK: - Workspace
// ============================================

struct Workspace: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var createdAt: Date
    var isActive: Bool
    var agentCount: Int
    var workflowCount: Int
    var tokenUsage: TokenUsage

    struct TokenUsage: Codable {
        var total: Int
        var usedToday: Int
        var limit: Int
    }

    static let preview = Workspace(
        id: "ws_001",
        name: "Production",
        description: "生产环境工作空间",
        createdAt: Date(),
        isActive: true,
        agentCount: 12,
        workflowCount: 8,
        tokenUsage: TokenUsage(total: 2400000, usedToday: 45000, limit: 5000000)
    )
}
