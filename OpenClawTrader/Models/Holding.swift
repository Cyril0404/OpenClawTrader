import Foundation

//
//  Holding.swift
//  OpenClawTrader
//
//  功能：持仓数据模型，包含持仓详情和盈亏计算
//

// ============================================
// MARK: - Holding
// ============================================

struct Holding: Identifiable, Codable {
    let id: String
    var symbol: String
    var name: String
    var shares: Int
    var averageCost: Double
    var currentPrice: Double
    var currency: String

    var marketValue: Double {
        Double(shares) * currentPrice
    }

    var costBasis: Double {
        Double(shares) * averageCost
    }

    var profitLoss: Double {
        marketValue - costBasis
    }

    var profitLossPercent: Double {
        guard costBasis > 0 else { return 0 }
        return (profitLoss / costBasis) * 100
    }

    var dayChange: Double
    var dayChangePercent: Double

    static let preview = Holding(
        id: "holding_001",
        symbol: "AAPL",
        name: "Apple Inc.",
        shares: 150,
        averageCost: 165.20,
        currentPrice: 178.50,
        currency: "USD",
        dayChange: 3.52,
        dayChangePercent: 2.34
    )

    static let previewList: [Holding] = [
        Holding(id: "holding_001", symbol: "AAPL", name: "Apple Inc.", shares: 150, averageCost: 165.20, currentPrice: 178.50,
                currency: "USD", dayChange: 3.52, dayChangePercent: 2.34),
        Holding(id: "holding_002", symbol: "NVDA", name: "NVIDIA Corp.", shares: 80, averageCost: 820.00, currentPrice: 875.20,
                currency: "USD", dayChange: -10.88, dayChangePercent: -1.25),
        Holding(id: "holding_003", symbol: "MSFT", name: "Microsoft Corp.", shares: 100, averageCost: 380.50, currentPrice: 415.80,
                currency: "USD", dayChange: 3.61, dayChangePercent: 0.87),
        Holding(id: "holding_004", symbol: "GOOGL", name: "Alphabet Inc.", shares: 50, averageCost: 140.00, currentPrice: 152.30,
                currency: "USD", dayChange: 2.05, dayChangePercent: 1.36)
    ]
}

// ============================================
// MARK: - Portfolio Summary
// ============================================

struct PortfolioSummary: Codable {
    var totalValue: Double
    var totalCost: Double
    var dayChange: Double
    var dayChangePercent: Double
    var totalProfitLoss: Double
    var totalProfitLossPercent: Double
    var holdings: [Holding]

    static let preview = PortfolioSummary(
        totalValue: 1284560.00,
        totalCost: 1150000.00,
        dayChange: 12450.00,
        dayChangePercent: 0.98,
        totalProfitLoss: 134560.00,
        totalProfitLossPercent: 11.70,
        holdings: Holding.previewList
    )
}
