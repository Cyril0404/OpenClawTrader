import Foundation

//
//  BacktestResult.swift
//  OpenClawTrader
//
//  功能：回测结果数据模型
//

// ============================================
// MARK: - 回测结果
// ============================================

struct BacktestResult: Identifiable {
    let id: UUID
    let stockCode: String
    let stockName: String
    let strategy: StrategyType
    let startDate: Date
    let endDate: Date
    let initialCapital: Double

    // 交易统计
    let totalTrades: Int
    let winTrades: Int
    let lossTrades: Int

    // 收益指标
    let totalReturn: Double
    let annualizedReturn: Double
    let benchmarkReturn: Double

    // 风险指标
    let maxDrawdown: Double
    let sharpeRatio: Double
    let volatility: Double

    // 收益曲线数据
    let equityCurve: [EquityPoint]

    init(
        id: UUID = UUID(),
        stockCode: String,
        stockName: String,
        strategy: StrategyType,
        startDate: Date,
        endDate: Date,
        initialCapital: Double,
        totalTrades: Int,
        winTrades: Int,
        lossTrades: Int,
        totalReturn: Double,
        annualizedReturn: Double,
        benchmarkReturn: Double,
        maxDrawdown: Double,
        sharpeRatio: Double,
        volatility: Double,
        equityCurve: [EquityPoint]
    ) {
        self.id = id
        self.stockCode = stockCode
        self.stockName = stockName
        self.strategy = strategy
        self.startDate = startDate
        self.endDate = startDate
        self.initialCapital = initialCapital
        self.totalTrades = totalTrades
        self.winTrades = winTrades
        self.lossTrades = lossTrades
        self.totalReturn = totalReturn
        self.annualizedReturn = annualizedReturn
        self.benchmarkReturn = benchmarkReturn
        self.maxDrawdown = maxDrawdown
        self.sharpeRatio = sharpeRatio
        self.volatility = volatility
        self.equityCurve = equityCurve
    }

    var winRate: Double {
        guard totalTrades > 0 else { return 0 }
        return Double(winTrades) / Double(totalTrades) * 100
    }
}

// ============================================
// MARK: - 收益曲线点
// ============================================

struct EquityPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
    let benchmark: Double

    init(id: UUID = UUID(), date: Date, value: Double, benchmark: Double) {
        self.id = id
        self.date = date
        self.value = value
        self.benchmark = benchmark
    }
}

// ============================================
// MARK: - 策略类型
// ============================================

enum StrategyType: String, CaseIterable, Identifiable {
    case maCross = "均线交叉"
    case rsi = "RSI超买超卖"
    case macdCross = "MACD交叉"
    case bollBreak = "布林带突破"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .maCross:
            return "金叉买入，死叉卖出"
        case .rsi:
            return "RSI<30买入，RSI>70卖出"
        case .macdCross:
            return "MACD金叉买入，死叉卖出"
        case .bollBreak:
            return "价格突破布林带上轨买入，下轨卖出"
        }
    }
}

// ============================================
// MARK: - 回测信号
// ============================================

struct BacktestSignal: Identifiable {
    let id: UUID
    let date: Date
    let type: SignalType
    let price: Double
    let quantity: Int
    let reason: String

    enum SignalType: String {
        case buy = "买入"
        case sell = "卖出"
    }
}

// ============================================
// MARK: - 回测参数
// ============================================

struct BacktestParams {
    var stockCode: String = "000001"
    var stockName: String = "平安银行"
    var strategy: StrategyType = .maCross
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
    var endDate: Date = Date()
    var initialCapital: Double = 100000
}
