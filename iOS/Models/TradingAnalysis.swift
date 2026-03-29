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

    // ===== 真实A股AI建议（基于神冢持仓2026-03-27）=====
    static let preview = TradingSuggestion(
        id: "sug_001",
        title: "芯源微今日涨幅4.63%，注意获利了结",
        description: "芯源微今日涨幅较大（+4.63%），处于相对高位，建议设置短期止盈位在180元附近，锁定部分收益",
        priority: .high,
        category: .stopLoss,
        potentialImpact: "可锁定收益，控制在高位回撤风险",
        timestamp: Date(),
        isRead: false
    )

    static let previewList: [TradingSuggestion] = [
        TradingSuggestion(id: "sug_001", title: "芯源微今日涨幅4.63%，注意获利了结", description: "芯源微今日涨幅较大（+4.63%），处于相对高位，建议设置短期止盈位在180元附近", priority: .high,
                          category: .stopLoss, potentialImpact: "可锁定收益，控制高位回撤风险", timestamp: Date(), isRead: false),
        TradingSuggestion(id: "sug_002", title: "兆易创新小幅回调，可适当加仓", description: "兆易创新今日小跌（-1.27%），若看好存储芯片周期反转逻辑，可在250元附近适度加仓", priority: .medium,
                          category: .timing, potentialImpact: "可降低持仓成本，提高潜在收益", timestamp: Date().addingTimeInterval(-3600), isRead: false),
        TradingSuggestion(id: "sug_003", title: "长芯博创换手率偏高（7.16%）", description: "长芯博创今日换手率达7.16%，属高位活跃状态，建议关注明日开盘走势，如高开低走需警惕", priority: .high,
                          category: .stopLoss, potentialImpact: "可规避高换手后的回调风险", timestamp: Date().addingTimeInterval(-7200), isRead: true),
        TradingSuggestion(id: "sug_004", title: "持仓集中度较高", description: "当前3只持仓均属硬科技赛道，建议适当配置1-2只消费或中字头标的，降低赛道集中风险", priority: .medium,
                          category: .diversification, potentialImpact: "可降低组合波动，提升风险调整收益", timestamp: Date().addingTimeInterval(-86400), isRead: true)
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

    // ===== 真实A股交易记录 =====
    static let previewList: [Trade] = [
        Trade(id: "trade_001", symbol: "300548", name: "长芯博创", type: .buy, shares: 1000, price: 138.50, commission: 15.0,
              timestamp: Date().addingTimeInterval(-86400 * 5), reason: "光通信赛道景气度高，长芯博创为FAU国内龙头"),
        Trade(id: "trade_002", symbol: "688037", name: "芯源微", type: .buy, shares: 500, price: 152.00, commission: 8.0,
              timestamp: Date().addingTimeInterval(-86400 * 3), reason: "半导体设备国产替代逻辑持续兑现"),
        Trade(id: "trade_003", symbol: "603986", name: "兆易创新", type: .buy, shares: 800, price: 245.00, commission: 12.0,
              timestamp: Date().addingTimeInterval(-86400 * 2), reason: "存储芯片周期反转明确，Q2业绩预期向好"),
    ]
}
