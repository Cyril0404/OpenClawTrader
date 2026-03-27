import Foundation

//
//  TradingService.swift
//  OpenClawTrader
//
//  功能：交易服务，管理持仓、交易分析、AI建议
//

// ============================================
// MARK: - Trading Service
// ============================================

@MainActor
class TradingService: ObservableObject {
    static let shared = TradingService()

    @Published var portfolio: PortfolioSummary?
    @Published var tradingStyle: TradingStyle?
    @Published var riskAssessment: RiskAssessment?
    @Published var suggestions: [TradingSuggestion] = []
    @Published var trades: [Trade] = []
    @Published var performance: PerformanceReport?

    @Published var isLoading = false
    @Published var error: String?

    private init() {
        loadMockData()
    }

    // MARK: - Mock Data

    private func loadMockData() {
        portfolio = PortfolioSummary.preview
        tradingStyle = TradingStyle.preview
        riskAssessment = RiskAssessment.preview
        suggestions = TradingSuggestion.previewList
        performance = PerformanceReport.preview

        trades = [
            Trade(id: "trade_001", symbol: "AAPL", name: "Apple Inc.", type: .buy, shares: 50, price: 175.20, commission: 1.0,
                  timestamp: Date().addingTimeInterval(-86400), reason: "看好科技板块"),
            Trade(id: "trade_002", symbol: "NVDA", name: "NVIDIA Corp.", type: .buy, shares: 20, price: 850.00, commission: 1.0,
                  timestamp: Date().addingTimeInterval(-172800), reason: "AI 概念持续火热"),
            Trade(id: "trade_003", symbol: "MSFT", name: "Microsoft Corp.", type: .sell, shares: 30, price: 410.50, commission: 1.0,
                  timestamp: Date().addingTimeInterval(-259200), reason: "获利了结"),
            Trade(id: "trade_004", symbol: "GOOGL", name: "Alphabet Inc.", type: .buy, shares: 25, price: 148.00, commission: 1.0,
                  timestamp: Date().addingTimeInterval(-345600), reason: "低估")
        ]
    }

    // MARK: - Holdings

    /// 导入持仓
    /// - Parameters:
    ///   - symbol: 股票代码
    ///   - shares: 持股数量
    ///   - averageCost: 平均成本
    ///   - currentPrice: 当前价格
    ///   - name: 股票名称
    func importHolding(symbol: String, shares: Int, averageCost: Double, currentPrice: Double, name: String) {
        let holding = Holding(
            id: "holding_\(UUID().uuidString.prefix(8))",
            symbol: symbol.uppercased(),
            name: name,
            shares: shares,
            averageCost: averageCost,
            currentPrice: currentPrice,
            currency: "USD",
            dayChange: 0,
            dayChangePercent: 0
        )

        if var p = portfolio {
            p.holdings.append(holding)
            recalculatePortfolio(&p)
            portfolio = p
        }
    }

    /// 更新持仓信息
    /// - Parameter holding: 更新后的持仓数据
    func updateHolding(_ holding: Holding) {
        guard var p = portfolio,
              let index = p.holdings.firstIndex(where: { $0.id == holding.id }) else { return }
        p.holdings[index] = holding
        recalculatePortfolio(&p)
        portfolio = p
    }

    /// 删除持仓
    /// - Parameter holding: 要删除的持仓
    func deleteHolding(_ holding: Holding) {
        guard var p = portfolio else { return }
        p.holdings.removeAll { $0.id == holding.id }
        recalculatePortfolio(&p)
        portfolio = p
    }

    private func recalculatePortfolio(_ portfolio: inout PortfolioSummary) {
        portfolio.totalValue = portfolio.holdings.reduce(0) { $0 + $1.marketValue }
        portfolio.totalCost = portfolio.holdings.reduce(0) { $0 + $1.costBasis }
        portfolio.totalProfitLoss = portfolio.totalValue - portfolio.totalCost
        portfolio.totalProfitLossPercent = portfolio.totalCost > 0 ? (portfolio.totalProfitLoss / portfolio.totalCost) * 100 : 0
    }

    // MARK: - Suggestions

    /// 标记建议为已读
    /// - Parameter suggestion: 要标记的建议
    func markSuggestionRead(_ suggestion: TradingSuggestion) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        suggestions[index].isRead = true
    }

    /// 忽略（删除）交易建议
    /// - Parameter suggestion: 要忽略的建议
    func dismissSuggestion(_ suggestion: TradingSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    // MARK: - Analysis Refresh

    /// 刷新交易分析数据
    func refreshAnalysis() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        tradingStyle = TradingStyle.preview
        riskAssessment = RiskAssessment.preview
        isLoading = false
    }
}
