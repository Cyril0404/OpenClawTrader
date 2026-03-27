import Foundation

//
//  TradingAnalysis.swift
//  OpenClawTrader
//
//  功能：交易分析数据模型，包含风格和风险评估
//

// ============================================
// MARK: - Trading Style
// ============================================

struct TradingStyle: Codable {
    var primaryStyle: StyleType
    var secondaryStyle: StyleType?
    var holdingPeriodPreference: HoldingPeriod
    var riskTolerance: RiskLevel
    var confidence: Double

    enum StyleType: String, Codable, CaseIterable {
        case trendFollower = "趋势跟踪"
        case reversalTrader = "反转交易"
        case valueInvestor = "价值投资"
        case eventDriven = "事件驱动"
        case sectorRotator = "板块轮动"
        case dayTrader = "日内交易"
        case swingTrader = "波段交易"
    }

    enum HoldingPeriod: String, Codable {
        case veryShort = "极短线 (<1天)"
        case short = "短线 (1-5天)"
        case medium = "中线 (5-30天)"
        case long = "长线 (30-90天)"
        case veryLong = "超长线 (>90天)"
    }

    enum RiskLevel: String, Codable {
        case conservative = "保守"
        case moderate = "稳健"
        case aggressive = "激进"
    }

    static let preview = TradingStyle(
        primaryStyle: .trendFollower,
        secondaryStyle: .swingTrader,
        holdingPeriodPreference: .short,
        riskTolerance: .moderate,
        confidence: 0.85
    )
}

// ============================================
// MARK: - Risk Assessment
// ============================================

struct RiskAssessment: Codable {
    var overallScore: Double
    var concentrationRisk: RiskFactor
    var volatilityExposure: RiskFactor
    var leverageUsage: RiskFactor
    var sectorDiversification: RiskFactor
    var liquidityRisk: RiskFactor

    struct RiskFactor: Codable {
        var score: Double
        var level: RiskLevel
        var description: String

        enum RiskLevel: String, Codable {
            case low = "低"
            case medium = "中"
            case high = "高"
        }
    }

    static let preview = RiskAssessment(
        overallScore: 6.5,
        concentrationRisk: RiskFactor(score: 0.65, level: .medium, description: "单一股票仓位偏重"),
        volatilityExposure: RiskFactor(score: 0.42, level: .low, description: "波动率暴露适中"),
        leverageUsage: RiskFactor(score: 0.18, level: .low, description: "未使用杠杆"),
        sectorDiversification: RiskFactor(score: 0.78, level: .low, description: "行业分布较分散"),
        liquidityRisk: RiskFactor(score: 0.25, level: .low, description: "持仓流动性良好")
    )
}

// ============================================
// MARK: - Trading Suggestion
// ============================================

struct TradingSuggestion: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var priority: Priority
    var category: Category
    var potentialImpact: String
    var timestamp: Date
    var isRead: Bool

    enum Priority: String, Codable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var color: String {
            switch self {
            case .high: return "E74C3C"
            case .medium: return "F39C12"
            case .low: return "8A8A8A"
            }
        }
    }

    enum Category: String, Codable, CaseIterable {
        case positionMgmt = "仓位管理"
        case stopLoss = "止损策略"
        case diversification = "分散投资"
        case timing = "交易时机"
        case habit = "交易习惯"

        var displayName: String { rawValue }
    }

    static let preview = TradingSuggestion(
        id: "sug_001",
        title: "仓位过于集中",
        description: "建议将 AAPL 持仓降低 20%，分散到其他科技股以降低风险",
        priority: .high,
        category: .positionMgmt,
        potentialImpact: "可降低 15% 的集中风险",
        timestamp: Date(),
        isRead: false
    )

    static let previewList: [TradingSuggestion] = [
        TradingSuggestion(id: "sug_001", title: "仓位过于集中", description: "建议将 AAPL 持仓降低 20%，分散到其他科技股", priority: .high,
                          category: .positionMgmt, potentialImpact: "可降低 15% 集中风险", timestamp: Date(), isRead: false),
        TradingSuggestion(id: "sug_002", title: "持仓周期偏短", description: "您的平均持仓周期为 5 天，可尝试延长至 14 天", priority: .medium,
                          category: .habit, potentialImpact: "可降低交易成本 30%", timestamp: Date().addingTimeInterval(-3600), isRead: false),
        TradingSuggestion(id: "sug_003", title: "建议设置止损", description: "NVDA 当前仓位建议设置 8% 止损位", priority: .high,
                          category: .stopLoss, potentialImpact: "可限制最大亏损", timestamp: Date().addingTimeInterval(-7200), isRead: true),
        TradingSuggestion(id: "sug_004", title: "考虑分批建仓", description: "GOOGL 可考虑分 3 批建仓，降低择时风险", priority: .medium,
                          category: .timing, potentialImpact: "可降低 10% 买入成本", timestamp: Date().addingTimeInterval(-86400), isRead: true)
    ]
}

// ============================================
// MARK: - Trade
// ============================================

struct Trade: Identifiable, Codable {
    let id: String
    var symbol: String
    var name: String
    var type: TradeType
    var shares: Int
    var price: Double
    var commission: Double
    var timestamp: Date
    var reason: String?

    enum TradeType: String, Codable {
        case buy = "买入"
        case sell = "卖出"
        case dividend = "分红"
        case split = "拆股"
    }

    var totalAmount: Double {
        Double(shares) * price + commission
    }
}
