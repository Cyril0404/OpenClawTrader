import Foundation

//
//  SentimentData.swift
//  OpenClawTrader
//
//  功能：舆情数据模型
//

// ============================================
// MARK: - 舆情数据
// ============================================

struct SentimentData: Identifiable {
    let id: UUID
    let stockCode: String
    let stockName: String
    let sentimentScore: Double  // -100 到 100，正面为正
    let bullishPercent: Double  // 唱多比例
    let bearishPercent: Double   // 唱空比例
    let neutralPercent: Double   // 中立比例
    let discussionCount: Int     // 讨论数量
    let trend: Double        // 热度趋势，相对于昨天
    let keywords: [String]       // 热门关键词
    let lastUpdated: Date

    var sentimentLabel: SentimentLabel {
        if sentimentScore >= 30 { return .bullish }
        if sentimentScore <= -30 { return .bearish }
        return .neutral
    }
}

enum SentimentLabel: String {
    case bullish = "唱多"
    case neutral = "中立"
    case bearish = "唱空"

    var color: String {
        switch self {
        case .bullish: return "green"
        case .neutral: return "gray"
        case .bearish: return "red"
        }
    }
}

// ============================================
// MARK: - 股票舆情榜单
// ============================================

struct SentimentRanking: Identifiable {
    let id: UUID
    let rank: Int
    let stockCode: String
    let stockName: String
    let sentimentScore: Double
    let trend: Double
    let discussionCount: Int

    init(id: UUID = UUID(), rank: Int, stockCode: String, stockName: String, sentimentScore: Double, trend: Double, discussionCount: Int) {
        self.id = id
        self.rank = rank
        self.stockCode = stockCode
        self.stockName = stockName
        self.sentimentScore = sentimentScore
        self.trend = trend
        self.discussionCount = discussionCount
    }
}

// ============================================
// MARK: - 社交媒体帖子
// ============================================

struct SocialPost: Identifiable {
    let id: UUID
    let platform: Platform
    let author: String
    let content: String
    let sentiment: SentimentLabel
    let sentimentScore: Double
    let likes: Int
    let comments: Int
    let shares: Int
    let postedAt: Date

    enum Platform: String {
        case twitter = "Twitter"
        case xueqiu = "雪球"
        case guba = "股吧"
        case weibo = "微博"
    }
}

// ============================================
// MARK: - Mock 数据
// ============================================

extension SentimentData {
    static func mock(stockCode: String = "000001", stockName: String = "平安银行") -> SentimentData {
        SentimentData(
            id: UUID(),
            stockCode: stockCode,
            stockName: stockName,
            sentimentScore: Double.random(in: -50...50),
            bullishPercent: Double.random(in: 20...60),
            bearishPercent: Double.random(in: 10...40),
            neutralPercent: Double.random(in: 20...40),
            discussionCount: Int.random(in: 1000...50000),
            trend: Double.random(in: -20...20),
            keywords: ["业绩增长", "银行股", "估值修复", "降息", "资产质量"],
            lastUpdated: Date()
        )
    }
}

extension SentimentRanking {
    static func mockList() -> [SentimentRanking] {
        let stocks = [
            ("600519", "贵州茅台"),
            ("000858", "五粮液"),
            ("000001", "平安银行"),
            ("600036", "招商银行"),
            ("601318", "中国平安"),
            ("000002", "万科A"),
            ("600000", "浦发银行")
        ]

        return stocks.enumerated().map { index, stock in
            SentimentRanking(
                rank: index + 1,
                stockCode: stock.0,
                stockName: stock.1,
                sentimentScore: Double.random(in: -50...50),
                trend: Double.random(in: -20...20),
                discussionCount: Int.random(in: 5000...100000)
            )
        }.sorted { $0.sentimentScore > $1.sentimentScore }
    }
}

extension SocialPost {
    static func mockList() -> [SocialPost] {
        [
            SocialPost(
                id: UUID(),
                platform: .xueqiu,
                author: "价值投资者",
                content: "\(Int.random(in: 10...50))块买的平安银行，目标价30，坚定持有！",
                sentiment: .bullish,
                sentimentScore: 75,
                likes: Int.random(in: 100...1000),
                comments: Int.random(in: 20...200),
                shares: Int.random(in: 10...50),
                postedAt: Date().addingTimeInterval(-3600)
            ),
            SocialPost(
                id: UUID(),
                platform: .guba,
                author: "短线王",
                content: "平安银行今日跌破均线，MACD死叉，短期看空",
                sentiment: .bearish,
                sentimentScore: -65,
                likes: Int.random(in: 50...300),
                comments: Int.random(in: 10...100),
                shares: Int.random(in: 5...30),
                postedAt: Date().addingTimeInterval(-7200)
            ),
            SocialPost(
                id: UUID(),
                platform: .twitter,
                author: "GlobalInvest",
                content: "中国银行股估值偏低，但需要等待更多政策信号",
                sentiment: .neutral,
                sentimentScore: 10,
                likes: Int.random(in: 50...200),
                comments: Int.random(in: 10...50),
                shares: Int.random(in: 5...20),
                postedAt: Date().addingTimeInterval(-14400)
            )
        ]
    }
}
