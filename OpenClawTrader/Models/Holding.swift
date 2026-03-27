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

    var todayPL: Double { dayChange }
    var totalPL: Double { totalProfitLoss }

    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥\(Int(totalValue))"
    }

    var formattedTodayPL: String {
        let sign = dayChange >= 0 ? "+" : ""
        return "\(sign)¥\(Int(abs(dayChange)))"
    }

    var formattedTotalPL: String {
        let sign = totalProfitLoss >= 0 ? "+" : ""
        return "\(sign)¥\(Int(abs(totalProfitLoss)))"
    }

    static let preview = PortfolioSummary(
        totalValue: 1284560.00,
        totalCost: 1150000.00,
        dayChange: 12450.00,
        dayChangePercent: 0.98,
        totalProfitLoss: 134560.00,
        totalProfitLossPercent: 11.70,
        holdings: Holding.previewList
    )

    var stockCount: Int {
        holdings.count
    }
}

// ============================================
// MARK: - Order (委托单)
// ============================================

struct Order: Identifiable, Codable {
    let id: String
    var symbol: String
    var name: String
    var type: OrderType
    var side: OrderSide
    var shares: Int
    var price: Double
    var status: OrderStatus
    var timestamp: Date
    var filledShares: Int
    var avgFillPrice: Double

    enum OrderType: String, Codable {
        case limit = "限价"
        case market = "市价"
        case stop = "止损"
        case stopLimit = "止损限价"
    }

    enum OrderSide: String, Codable {
        case buy = "买入"
        case sell = "卖出"
    }

    enum OrderStatus: String, Codable {
        case pending = "pending"      // 待成交
        case partiallyFilled = "partial" // 部分成交
        case filled = "filled"      // 已成交
        case cancelled = "cancelled" // 已取消
        case rejected = "rejected"   // 已拒绝

        var displayName: String {
            switch self {
            case .pending: return "待成交"
            case .partiallyFilled: return "部分成交"
            case .filled: return "已成交"
            case .cancelled: return "已取消"
            case .rejected: return "已拒绝"
            }
        }
    }

    var totalAmount: Double {
        Double(shares) * price
    }

    var isActive: Bool {
        status == .pending || status == .partiallyFilled
    }

    static let preview = Order(
        id: "order_001",
        symbol: "AAPL",
        name: "Apple Inc.",
        type: .limit,
        side: .buy,
        shares: 50,
        price: 180.00,
        status: .pending,
        timestamp: Date(),
        filledShares: 0,
        avgFillPrice: 0
    )

    static let previewList: [Order] = [
        Order(id: "order_001", symbol: "AAPL", name: "Apple Inc.", type: .limit, side: .buy, shares: 50, price: 180.00, status: .pending, timestamp: Date(), filledShares: 0, avgFillPrice: 0),
        Order(id: "order_002", symbol: "TSLA", name: "Tesla Inc.", type: .limit, side: .sell, shares: 20, price: 250.00, status: .partiallyFilled, timestamp: Date().addingTimeInterval(-3600), filledShares: 10, avgFillPrice: 248.50),
        Order(id: "order_003", symbol: "NVDA", name: "NVIDIA Corp.", type: .market, side: .buy, shares: 30, price: 875.00, status: .filled, timestamp: Date().addingTimeInterval(-86400), filledShares: 30, avgFillPrice: 873.20)
    ]
}
