import Foundation

//
//  Skill.swift
//  OpenClawTrader
//
//  功能：OpenClaw 技能模型
//

// ============================================
// MARK: - Skill Model
// ============================================

struct Skill: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    var isEnabled: Bool
    let icon: String
    let category: SkillCategory

    enum SkillCategory: String, Codable {
        case analysis = "分析"
        case trading = "交易"
        case risk = "风险"
        case information = "资讯"
        case recommendation = "推荐"
        case quant = "量化"
    }
}

// ============================================
// MARK: - Mock Skills
// ============================================

extension Skill {
    static let mockSkills: [Skill] = [
        Skill(
            id: "stock_analysis",
            name: "股票分析",
            description: "分析K线、技术指标、财务数据",
            isEnabled: true,
            icon: "chart.line.uptrend.xyaxis",
            category: .analysis
        ),
        Skill(
            id: "trading_execution",
            name: "交易执行",
            description: "执行买卖交易指令",
            isEnabled: false,
            icon: "arrow.left.arrow.right",
            category: .trading
        ),
        Skill(
            id: "risk_assessment",
            name: "风险评估",
            description: "评估持仓风险和仓位管理",
            isEnabled: true,
            icon: "exclamationmark.shield",
            category: .risk
        ),
        Skill(
            id: "news_aggregation",
            name: "资讯聚合",
            description: "实时获取市场资讯和公告",
            isEnabled: true,
            icon: "newspaper",
            category: .information
        ),
        Skill(
            id: "ai_recommendation",
            name: "智能推荐",
            description: "基于AI的投资建议",
            isEnabled: true,
            icon: "brain",
            category: .recommendation
        ),
        Skill(
            id: "quant_strategy",
            name: "量化策略",
            description: "回测和量化策略执行",
            isEnabled: false,
            icon: "function",
            category: .quant
        ),
        Skill(
            id: "portfolio_optimization",
            name: "组合优化",
            description: "优化投资组合配置",
            isEnabled: false,
            icon: "chart.pie",
            category: .analysis
        ),
        Skill(
            id: "price_alert",
            name: "价格提醒",
            description: "自定义价格预警通知",
            isEnabled: true,
            icon: "bell.badge",
            category: .information
        )
    ]
}
