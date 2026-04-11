import Foundation

//
//  UserProfile.swift
//  OpenClawTrader
//
//  用户投资画像数据模型
//  对应 Python profile_manager.py 的 generate_profile() 输出
//

// MARK: - UserProfile

/// 用户投资画像
struct UserProfile: Codable {
    // 基础统计
    var totalTrades: Int = 0
    var doneTrades: Int = 0
    var cancelCount: Int = 0
    var cancelRate: Double = 0.0
    var completionRate: Double = 0.0
    var buyCount: Int = 0
    var sellCount: Int = 0
    var directionRatio: [String: Double] = [:]

    // 风格分析
    var style: String = ""
    var styleConfidence: String = ""
    var avgHoldingDays: Double = 0.0
    var holdingDistribution: [String: Int] = [:]

    // 盈亏
    var winRate: Double = 0.0
    var estimatedProfit: String = ""
    var estimatedLoss: String = ""
    var profitLossRatio: String = ""
    var netPnl: Double = 0.0

    // 板块偏好
    var sectorPreference: String = ""
    var sectorDetail: [String: Int] = [:]
    var marketCapPreference: String = ""

    // 时机特征
    var timingPattern: String = ""
    var chasingScore: String = ""
    var bottomFishingScore: String = ""
    var timingConfidence: String = ""

    // 重点股票
    var topStocks: [String] = []
    var stockDetail: [String: StockInfo] = [:]

    // 风险预警
    var riskWarnings: [String] = []

    // 洞察
    var insights: [String] = []

    // 数据质量
    var audit: AuditResult = AuditResult()

    // 置信度
    var confidence: String = "低"

    // 风险等级
    var riskLevel: String = "中"

    // v1.2 增强字段
    var oneLiner: String = ""
    var personalityTags: PersonalityTags = PersonalityTags()
    var capabilityRadar: [String: CapabilityDimension] = [:]
    var benchmark: BenchmarkResult?
    var behaviorInsights: [String] = []
    var personalizedAdvice: [PersonalizedAdvice] = []
    var growthTracking: GrowthTracking?
    var disclaimer: String = ""

    var generatedAt: String = ""

    enum CodingKeys: String, CodingKey {
        case totalTrades = "total_trades"
        case doneTrades = "done_trades"
        case cancelCount = "cancel_count"
        case cancelRate = "cancel_rate"
        case completionRate = "completion_rate"
        case buyCount = "buy_count"
        case sellCount = "sell_count"
        case directionRatio = "direction_ratio"
        case style
        case styleConfidence = "style_confidence"
        case avgHoldingDays = "avg_holding_days"
        case holdingDistribution = "holding_distribution"
        case winRate = "win_rate"
        case estimatedProfit = "estimated_profit"
        case estimatedLoss = "estimated_loss"
        case profitLossRatio = "profit_loss_ratio"
        case netPnl = "net_pnl"
        case sectorPreference = "sector_preference"
        case sectorDetail = "sector_detail"
        case marketCapPreference = "market_cap_preference"
        case timingPattern = "timing_pattern"
        case chasingScore = "chasing_score"
        case bottomFishingScore = "bottom_fishing_score"
        case timingConfidence = "timing_confidence"
        case topStocks = "top_stocks"
        case stockDetail = "stock_detail"
        case riskWarnings = "risk_warnings"
        case insights
        case audit
        case confidence
        case riskLevel = "risk_level"
        case oneLiner = "one_liner"
        case personalityTags = "personality_tags"
        case capabilityRadar = "capability_radar"
        case benchmark
        case behaviorInsights = "behavior_insights"
        case personalizedAdvice = "personalized_advice"
        case growthTracking = "growth_tracking"
        case disclaimer
        case generatedAt = "generated_at"
    }
}

// MARK: - Supporting Types

struct StockInfo: Codable {
    var name: String = ""
    var sector: String = ""
    var cap: String = ""
}

struct AuditResult: Codable {
    var passed: Bool = true
    var issues: [String] = []
    var totalIssues: Int = 0

    enum CodingKeys: String, CodingKey {
        case passed
        case issues
        case totalIssues = "total_issues"
    }
}

struct PersonalityTags: Codable {
    var primary: [String] = []
    var secondary: [String] = []
    var summary: String = ""
}

struct CapabilityDimension: Codable {
    var score: Int = 0
    var raw: String = ""
    var reason: String = ""
}

struct BenchmarkResult: Codable {
    var available: Bool = false
    var reason: String?
    var thisMonth: String = ""
    var lastMonth: String = ""
    var cancelRate: MonthlyChange?
    var avgHoldingDays: MonthlyChange?
    var tradeCount: MonthlyChange?

    enum CodingKeys: String, CodingKey {
        case available
        case reason
        case thisMonth = "this_month"
        case lastMonth = "last_month"
        case cancelRate = "cancel_rate"
        case avgHoldingDays = "avg_holding_days"
        case tradeCount = "trade_count"
    }
}

struct MonthlyChange: Codable {
    var thisMonth: Double = 0
    var lastMonth: Double = 0
    var change: String = ""
    var trend: String = ""
    var emoji: String = ""

    enum CodingKeys: String, CodingKey {
        case thisMonth = "this_month"
        case lastMonth = "last_month"
        case change
        case trend
        case emoji
    }
}

struct PersonalizedAdvice: Codable {
    var title: String = ""
    var content: String = ""
    var why: String = ""
    var priority: String = "中"

    enum CodingKeys: String, CodingKey {
        case title
        case content
        case why
        case priority
    }
}

struct GrowthTracking: Codable {
    var available: Bool = false
    var reason: String?
    var thisMonth: String = ""
    var lastMonth: String = ""
    var changes: [String] = []
    var summary: String = ""

    enum CodingKeys: String, CodingKey {
        case available
        case reason
        case thisMonth = "this_month"
        case lastMonth = "last_month"
        case changes
        case summary
    }
}

// MARK: - Empty Profile

extension UserProfile {
    static func empty() -> UserProfile {
        UserProfile()
    }

    static func insufficientData() -> UserProfile {
        var profile = UserProfile()
        profile.confidence = "低"
        profile.style = "数据不足"
        profile.oneLiner = "暂无足够交易数据，请先上传委托单"
        profile.insights = ["请上传交易记录以生成投资画像"]
        return profile
    }
}

// MARK: - Profile Summary (简化展示)

struct ProfileSummary: Codable {
    var style: String
    var winRate: Double
    var cancelRate: Double
    var confidence: String
    var avgHoldingDays: Double
    var oneLiner: String
    var personalityTags: [String]
    var riskLevel: String

    init(from profile: UserProfile) {
        self.style = profile.style
        self.winRate = profile.winRate
        self.cancelRate = profile.cancelRate
        self.confidence = profile.confidence
        self.avgHoldingDays = profile.avgHoldingDays
        self.oneLiner = profile.oneLiner
        self.personalityTags = profile.personalityTags.primary
        self.riskLevel = profile.riskLevel
    }
}
