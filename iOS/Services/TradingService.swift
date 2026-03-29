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
    @Published var orders: [Order] = []
    @Published var performance: PerformanceReport?

    @Published var isLoading = false
    @Published var error: String?

    private init() {
        // 初始为空，等待数据加载
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

    // MARK: - Orders (委托单)

    /// 导入委托单
    func importOrder(symbol: String, name: String, type: Order.OrderType, side: Order.OrderSide, shares: Int, price: Double) {
        let order = Order(
            id: "order_\(UUID().uuidString.prefix(8))",
            symbol: symbol.uppercased(),
            name: name,
            type: type,
            side: side,
            shares: shares,
            price: price,
            status: .pending,
            timestamp: Date(),
            filledShares: 0,
            avgFillPrice: 0
        )
        orders.append(order)
    }

    /// 取消委托单
    func cancelOrder(_ order: Order) {
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else { return }
        orders[index].status = .cancelled
    }

    /// 获取活跃委托单（待成交和部分成交）
    var activeOrders: [Order] {
        orders.filter { $0.isActive }
    }

    /// 获取已成交委托单
    var filledOrders: [Order] {
        orders.filter { $0.status == .filled }
    }

    /// AI 分析交易风格（结合成交和委托单）
    func analyzeTradingStyle() -> TradingStyle {
        // 结合成交记录和委托单分析交易风格
        // 待成交的委托单反映了用户的交易意图
        // 已成交的委托单反映了用户的交易执行

        let activeBuyOrders = activeOrders.filter { $0.side == .buy }
        let activeSellOrders = activeOrders.filter { $0.side == .sell }

        // 分析买入倾向（反映趋势跟踪或价值投资）
        let buyPressure = Double(activeBuyOrders.count) / max(1, Double(orders.count))

        // 分析限价单使用（反映谨慎程度）
        let limitOrderRatio = Double(orders.filter { $0.type == .limit }.count) / max(1, Double(orders.count))

        // 分析持仓周期偏好（基于成交记录）
        let avgHoldingDays = calculateAverageHoldingPeriod()

        // 判断主要风格
        var primaryStyle: TradingStyle.StyleType = .swingTrader
        if avgHoldingDays < 1 {
            primaryStyle = .dayTrader
        } else if avgHoldingDays < 5 {
            primaryStyle = .trendFollower
        } else if avgHoldingDays < 30 {
            primaryStyle = .swingTrader
        } else {
            primaryStyle = .valueInvestor
        }

        // 判断持仓周期
        var holdingPeriod: TradingStyle.HoldingPeriod = .short
        if avgHoldingDays < 1 {
            holdingPeriod = .veryShort
        } else if avgHoldingDays < 5 {
            holdingPeriod = .short
        } else if avgHoldingDays < 30 {
            holdingPeriod = .medium
        } else if avgHoldingDays < 90 {
            holdingPeriod = .long
        } else {
            holdingPeriod = .veryLong
        }

        return TradingStyle(
            primaryStyle: primaryStyle,
            secondaryStyle: buyPressure > 0.6 ? .trendFollower : (buyPressure < 0.4 ? .reversalTrader : nil),
            holdingPeriodPreference: holdingPeriod,
            riskTolerance: limitOrderRatio > 0.7 ? .conservative : (limitOrderRatio > 0.4 ? .moderate : .aggressive),
            confidence: 0.75
        )
    }

    private func calculateAverageHoldingPeriod() -> Double {
        // 计算平均持仓天数（简化版本）
        guard !trades.isEmpty else { return 5.0 }
        return 5.0 // 默认5天
    }

    // MARK: - Reset

    /// 重置所有交易数据（注销账号时调用）
    func reset() {
        portfolio = nil
        tradingStyle = nil
        riskAssessment = nil
        suggestions = []
        trades = []
        orders = []
        performance = nil
        error = nil
    }
}
