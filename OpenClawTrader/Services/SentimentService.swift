import Foundation

//
//  SentimentService.swift
//  OpenClawTrader
//
//  功能：舆情分析服务
//

// ============================================
// MARK: - Sentiment Service
// ============================================

@MainActor
class SentimentService: ObservableObject {
    static let shared = SentimentService()

    @Published var stockSentiment: SentimentData?
    @Published var rankings: [SentimentRanking] = []
    @Published var hotPosts: [SocialPost] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - 获取股票舆情

    func fetchSentiment(stockCode: String, stockName: String) async {
        isLoading = true
        error = nil

        // TODO: 调用真实API获取舆情数据
        // let response: SentimentResponse = try await APIClient.shared.request("/v1/sentiment/\(stockCode)")

        // Mock数据
        try? await Task.sleep(nanoseconds: 500_000_000)
        stockSentiment = SentimentData.mock(stockCode: stockCode, stockName: stockName)

        isLoading = false
    }

    // MARK: - 获取舆情榜单

    func fetchRankings() async {
        isLoading = true
        error = nil

        // TODO: 调用真实API
        // let response: [SentimentRankingResponse] = try await APIClient.shared.request("/v1/sentiment/rankings")

        // Mock数据
        try? await Task.sleep(nanoseconds: 500_000_000)
        rankings = SentimentRanking.mockList()

        isLoading = false
    }

    // MARK: - 获取热门帖子

    func fetchHotPosts() async {
        isLoading = true
        error = nil

        // TODO: 调用真实API
        // let response: [SocialPostResponse] = try await APIClient.shared.request("/v1/sentiment/hot")

        // Mock数据
        try? await Task.sleep(nanoseconds: 500_000_000)
        hotPosts = SocialPost.mockList()

        isLoading = false
    }

    // MARK: - 搜索股票舆情

    func searchStocks(keyword: String) -> [SentimentRanking] {
        return rankings.filter {
            $0.stockName.contains(keyword) || $0.stockCode.contains(keyword)
        }
    }
}
