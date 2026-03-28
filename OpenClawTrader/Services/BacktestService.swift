import Foundation

//
//  BacktestService.swift
//  OpenClawTrader
//
//  功能：策略回测服务
//

// ============================================
// MARK: - Backtest Service
// ============================================

@MainActor
class BacktestService: ObservableObject {
    static let shared = BacktestService()

    @Published var result: BacktestResult?
    @Published var signals: [BacktestSignal] = []
    @Published var isLoading = false
    @Published var error: String?

    @Published var params = BacktestParams()

    private init() {}

    // MARK: - 运行回测

    func runBacktest() async {
        isLoading = true
        error = nil
        signals = []

        // 获取K线数据
        let klineData = KLineData.mockData(days: 120)

        // 根据策略类型运行回测
        let (trades, equityCurve) = calculateBacktest(
            data: klineData,
            strategy: params.strategy,
            initialCapital: params.initialCapital
        )

        // 计算统计指标
        let totalReturn = calculateTotalReturn(equityCurve: equityCurve)
        let benchmarkReturn = calculateBenchmarkReturn(data: klineData)
        let maxDrawdown = calculateMaxDrawdown(equityCurve: equityCurve)
        let sharpeRatio = calculateSharpeRatio(equityCurve: equityCurve)
        let volatility = calculateVolatility(equityCurve: equityCurve)

        let winTrades = trades.filter { $0.type == .sell && $0.profit > 0 }.count
        let lossTrades = trades.filter { $0.type == .sell && $0.profit <= 0 }.count

        result = BacktestResult(
            stockCode: params.stockCode,
            stockName: params.stockName,
            strategy: params.strategy,
            startDate: params.startDate,
            endDate: params.endDate,
            initialCapital: params.initialCapital,
            totalTrades: trades.count,
            winTrades: winTrades,
            lossTrades: lossTrades,
            totalReturn: totalReturn,
            annualizedReturn: totalReturn * 2, // 简化估算
            benchmarkReturn: benchmarkReturn,
            maxDrawdown: maxDrawdown,
            sharpeRatio: sharpeRatio,
            volatility: volatility,
            equityCurve: equityCurve
        )

        isLoading = false
    }

    // MARK: - 回测计算

    private func calculateBacktest(
        data: [KLineData],
        strategy: StrategyType,
        initialCapital: Double
    ) -> ([TradeRecord], [EquityPoint]) {
        var capital = initialCapital
        var position = 0
        var cash = initialCapital
        var trades: [TradeRecord] = []
        var equityCurve: [EquityPoint] = []

        let closes = data.map { $0.close }
        let ma5 = calculateMA(prices: closes, period: 5)
        let ma20 = calculateMA(prices: closes, period: 20)
        let rsi = calculateRSI(prices: closes)
        let macd = calculateMACDSignal(data: data)

        for i in 20..<data.count {
            let candle = data[i]
            let benchmarkValue = candle.close / data[20].close * initialCapital

            switch strategy {
            case .maCross:
                // 均线交叉策略
                if let ma5Val = ma5[safe: i],
                   let ma5Prev = ma5[safe: i-1],
                   let ma20Prev = ma20[safe: i-1],
                   let ma20Val = ma20[safe: i] {
                    if ma5Val > ma20Val && ma5Prev <= ma20Prev && position == 0 {
                        // 金叉买入
                        position = Int((cash / candle.close).rounded(.down))
                        cash -= Double(position) * candle.close
                        trades.append(TradeRecord(date: candle.date, type: .buy, price: candle.close, quantity: position, profit: 0))
                    } else if ma5Val < ma20Val && ma5Prev >= ma20Prev && position > 0 {
                        // 死叉卖出
                        cash += Double(position) * candle.close
                        let profit = (candle.close - trades.last!.price) * Double(position)
                        trades.append(TradeRecord(date: candle.date, type: .sell, price: candle.close, quantity: position, profit: profit))
                        position = 0
                    }
                }

            case .rsi:
                // RSI策略
                if let rsiVal = rsi[safe: i] {
                    if rsiVal < 30 && position == 0 {
                        position = Int((cash / candle.close).rounded(.down))
                        cash -= Double(position) * candle.close
                        trades.append(TradeRecord(date: candle.date, type: .buy, price: candle.close, quantity: position, profit: 0))
                    } else if rsiVal > 70 && position > 0 {
                        cash += Double(position) * candle.close
                        let profit = (candle.close - trades.last!.price) * Double(position)
                        trades.append(TradeRecord(date: candle.date, type: .sell, price: candle.close, quantity: position, profit: profit))
                        position = 0
                    }
                }

            case .macdCross:
                // MACD交叉策略
                if let macdVal = macd[safe: i], let macdPrev = macd[safe: i-1] {
                    if macdVal > 0 && macdPrev <= 0 && position == 0 {
                        position = Int((cash / candle.close).rounded(.down))
                        cash -= Double(position) * candle.close
                        trades.append(TradeRecord(date: candle.date, type: .buy, price: candle.close, quantity: position, profit: 0))
                    } else if macdVal < 0 && macdPrev >= 0 && position > 0 {
                        cash += Double(position) * candle.close
                        let profit = (candle.close - trades.last!.price) * Double(position)
                        trades.append(TradeRecord(date: candle.date, type: .sell, price: candle.close, quantity: position, profit: profit))
                        position = 0
                    }
                }

            case .bollBreak:
                // 布林带突破策略（简化版）
                let bollMiddle = ma20[safe: i] ?? candle.close
                let std = calculateStdDev(prices: Array(closes[max(0, i-20)...i]))
                let upper = bollMiddle + 2 * std
                let lower = bollMiddle - 2 * std

                if candle.close < lower && position == 0 {
                    position = Int((cash / candle.close).rounded(.down))
                    cash -= Double(position) * candle.close
                    trades.append(TradeRecord(date: candle.date, type: .buy, price: candle.close, quantity: position, profit: 0))
                } else if candle.close > upper && position > 0 {
                    cash += Double(position) * candle.close
                    let profit = (candle.close - trades.last!.price) * Double(position)
                    trades.append(TradeRecord(date: candle.date, type: .sell, price: candle.close, quantity: position, profit: profit))
                    position = 0
                }
            }

            let equity = cash + Double(position) * candle.close
            equityCurve.append(EquityPoint(
                date: candle.date,
                value: equity,
                benchmark: benchmarkValue
            ))
        }

        return (trades, equityCurve)
    }

    // MARK: - 技术指标计算

    private func calculateMA(prices: [Double], period: Int) -> [Double] {
        var result: [Double] = Array(repeating: 0, count: period - 1)
        for i in (period - 1)..<prices.count {
            let slice = prices[(i - period + 1)...i]
            result.append(slice.reduce(0, +) / Double(period))
        }
        return result
    }

    private func calculateRSI(prices: [Double], period: Int = 6) -> [Double] {
        var result: [Double] = Array(repeating: 0, count: period)

        guard prices.count > period else { return result }

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<prices.count {
            let change = prices[i] - prices[i - 1]
            gains.append(max(0, change))
            losses.append(max(0, -change))
        }

        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)

        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)

            let rs = avgLoss == 0 ? 100 : avgGain / avgLoss
            result.append(100 - (100 / (1 + rs)))
        }

        return result
    }

    private func calculateMACDSignal(data: [KLineData]) -> [Double] {
        let closes = data.map { $0.close }
        let ema12 = calculateEMA(prices: closes, period: 12)
        let ema26 = calculateEMA(prices: closes, period: 26)

        var result: [Double] = Array(repeating: 0, count: 26)
        for i in 26..<closes.count {
            let dif = ema12[i - 26 + 12] - ema26[i]
            result.append(dif)
        }
        return result
    }

    private func calculateEMA(prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period else { return [] }
        var ema: [Double] = []
        let multiplier = 2.0 / Double(period + 1)
        let sma = prices[0..<period].reduce(0, +) / Double(period)
        ema.append(sma)
        for i in period..<prices.count {
            let newEma = (prices[i] - ema.last!) * multiplier + ema.last!
            ema.append(newEma)
        }
        return ema
    }

    private func calculateStdDev(prices: [Double]) -> Double {
        guard !prices.isEmpty else { return 0 }
        let mean = prices.reduce(0, +) / Double(prices.count)
        let variance = prices.reduce(0) { $0 + pow($1 - mean, 2) } / Double(prices.count)
        return sqrt(variance)
    }

    // MARK: - 统计指标计算

    private func calculateTotalReturn(equityCurve: [EquityPoint]) -> Double {
        guard let first = equityCurve.first, let last = equityCurve.last else { return 0 }
        return (last.value - first.value) / first.value * 100
    }

    private func calculateBenchmarkReturn(data: [KLineData]) -> Double {
        guard data.count > 1 else { return 0 }
        return (data.last!.close - data.first!.open) / data.first!.open * 100
    }

    private func calculateMaxDrawdown(equityCurve: [EquityPoint]) -> Double {
        var maxValue = equityCurve.first?.value ?? 0
        var maxDrawdown = 0.0
        for point in equityCurve {
            maxValue = max(maxValue, point.value)
            let drawdown = (maxValue - point.value) / maxValue * 100
            maxDrawdown = max(maxDrawdown, drawdown)
        }
        return maxDrawdown
    }

    private func calculateSharpeRatio(equityCurve: [EquityPoint]) -> Double {
        guard equityCurve.count > 1 else { return 0 }
        let returns = zip(equityCurve, equityCurve.dropFirst()).map { ($1.value - $0.value) / $0.value }
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let stdDev = sqrt(returns.reduce(0) { $0 + pow($1 - avgReturn, 2) } / Double(returns.count))
        return stdDev == 0 ? 0 : avgReturn / stdDev * sqrt(252) // 年化
    }

    private func calculateVolatility(equityCurve: [EquityPoint]) -> Double {
        guard equityCurve.count > 1 else { return 0 }
        let returns = zip(equityCurve, equityCurve.dropFirst()).map { ($1.value - $0.value) / $0.value }
        let stdDev = sqrt(returns.reduce(0) { $0 + pow($1, 2) } / Double(returns.count))
        return stdDev * sqrt(252) * 100 // 年化波动率
    }
}

// ============================================
// MARK: - 交易记录
// ============================================

struct TradeRecord: Identifiable {
    let id = UUID()
    let date: Date
    let type: TradeType
    let price: Double
    let quantity: Int
    let profit: Double

    enum TradeType {
        case buy
        case sell
    }
}

// ============================================
// MARK: - Array Extension
// ============================================

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
