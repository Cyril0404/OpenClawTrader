import Foundation

//
//  Holding.swift
//  OpenClawTrader
//
//  功能：持仓数据模型（含真实A股数据，今日收盘价）
//  数据更新：stock_data_writer.py 每5分钟自动更新
//

// ============================================
// MARK: - Holding
// ============================================

struct Holding: Identifiable, Codable {
    let id: String
    var symbol: String      // 股票代码，如 "300548"
    var name: String       // 股票名称，如 "长芯博创"
    var shares: Int        // 持股数量
    var averageCost: Double // 平均成本
    var currentPrice: Double // 当前价格
    var currency: String = "CNY"

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

    var dayChange: Double     // 今日涨跌额
    var dayChangePercent: Double // 今日涨跌幅 %

    // ===== 真实A股持仓示例（神冢自选股 2026-03-27收盘数据）=====
    static let realStocks: [Holding] = [
        Holding(
            id: "holding_300548",
            symbol: "300548",
            name: "长芯博创",
            shares: 1000,
            averageCost: 138.50,
            currentPrice: 150.70,
            dayChange: 1.92,
            dayChangePercent: 1.30
        ),
        Holding(
            id: "holding_688037",
            symbol: "688037",
            name: "芯源微",
            shares: 500,
            averageCost: 152.00,
            currentPrice: 171.60,
            dayChange: 7.58,
            dayChangePercent: 4.63
        ),
        Holding(
            id: "holding_603986",
            symbol: "603986",
            name: "兆易创新",
            shares: 800,
            averageCost: 245.00,
            currentPrice: 258.66,
            dayChange: -3.33,
            dayChangePercent: -1.27
        )
    ]

    static let preview = realStocks[0]
    static let previewList: [Holding] = realStocks
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
    var stockCount: Int { holdings.count }

    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalValue)) ?? "¥\(String(format:"%.2f", totalValue))"
    }

    var formattedTodayPL: String {
        let sign = dayChange >= 0 ? "+" : ""
        return "\(sign)¥\(String(format:"%.2f", abs(dayChange)))"
    }

    var formattedTotalPL: String {
        let sign = totalProfitLoss >= 0 ? "+" : ""
        return "\(sign)¥\(String(format:"%.2f", abs(totalProfitLoss)))"
    }

    // 从真实持仓计算汇总数据
    static let fromRealStocks: PortfolioSummary = {
        let holdings = Holding.realStocks
        let totalValue = holdings.reduce(0) { $0 + $1.marketValue }
        let totalCost = holdings.reduce(0) { $0 + $1.costBasis }
        let dayChange = holdings.reduce(0) { $0 + ($1.currentPrice * Double($1.shares) * $1.dayChangePercent / 100) }
        let dayChangePercent = totalValue > 0 ? dayChange / (totalValue - dayChange) * 100 : 0
        return PortfolioSummary(
            totalValue: totalValue,
            totalCost: totalCost,
            dayChange: dayChange,
            dayChangePercent: dayChangePercent,
            totalProfitLoss: totalValue - totalCost,
            totalProfitLossPercent: totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0,
            holdings: holdings
        )
    }()

    static let preview = fromRealStocks
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
        case pending = "pending"
        case partiallyFilled = "partial"
        case filled = "filled"
        case cancelled = "cancelled"
        case rejected = "rejected"

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
        symbol: "300548",
        name: "长芯博创",
        type: .limit,
        side: .buy,
        shares: 100,
        price: 148.00,
        status: .pending,
        timestamp: Date(),
        filledShares: 0,
        avgFillPrice: 0
    )

    static let previewList: [Order] = [
        Order(id: "order_001", symbol: "300548", name: "长芯博创", type: .limit, side: .buy, shares: 100, price: 148.00, status: .pending, timestamp: Date(), filledShares: 0, avgFillPrice: 0),
        Order(id: "order_002", symbol: "688037", name: "芯源微", type: .limit, side: .sell, shares: 50, price: 175.00, status: .filled, timestamp: Date().addingTimeInterval(-3600), filledShares: 50, avgFillPrice: 171.60)
    ]
}
