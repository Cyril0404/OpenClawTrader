import Foundation

//
//  StockDataService.swift
//  OpenClawTrader
//
//  功能：股票数据服务，获取行情和技术指标
//

// ============================================
// MARK: - Stock Data Service
// ============================================

@MainActor
class StockDataService: ObservableObject {
    static let shared = StockDataService()

    @Published var klineData: [KLineData] = []
    @Published var indicators: TechnicalIndicators = .empty
    @Published var currentStock: StockInfo?
    @Published var isLoading = false
    @Published var error: String?

    @Published var selectedPeriod: KLinePeriod = .daily
    @Published var selectedIndicators: Set<IndicatorType> = [.ma, .macd]

    private let gatewayBaseURL = "http://localhost:18789"

    private init() {}

    // MARK: - 获取K线数据

    func fetchKLineData(stockCode: String, period: KLinePeriod = .daily) async {
        isLoading = true
        error = nil

        // TODO: 调用真实API
        // let response: [KLineResponse] = try await APIClient.shared.request("/v1/stock/\(stockCode)/kline?period=\(period.rawValue)")

        currentStock = StockInfo(id: stockCode, name: stockCodeToName(stockCode), market: "深交所")

        isLoading = false
    }

    // MARK: - 计算技术指标

    private func calculateIndicators(data: [KLineData]) -> TechnicalIndicators {
        let closes = data.map { $0.close }

        let ma5 = calculateMA(prices: closes, period: 5)
        let ma10 = calculateMA(prices: closes, period: 10)
        let ma20 = calculateMA(prices: closes, period: 20)
        let ma60 = calculateMA(prices: closes, period: 60)

        let macd = calculateMACD(prices: closes)
        let kdj = calculateKDJ(data: data)
        let rsi = calculateRSI(prices: closes)
        let boll = calculateBollingerBands(prices: closes)

        return TechnicalIndicators(
            ma5: ma5, ma10: ma10, ma20: ma20, ma60: ma60,
            macd: macd, kdj: kdj, rsi: rsi, boll: boll
        )
    }

    // MARK: - 均线计算

    private func calculateMA(prices: [Double], period: Int) -> [Double?] {
        var result: [Double?] = Array(repeating: nil, count: period - 1)

        for i in (period - 1)..<prices.count {
            let slice = prices[(i - period + 1)...i]
            let avg = slice.reduce(0, +) / Double(period)
            result.append(avg)
        }

        return result
    }

    // MARK: - MACD计算

    private func calculateMACD(prices: [Double], fast: Int = 12, slow: Int = 26, signal: Int = 9) -> MACDData {
        let emaFast = calculateEMA(prices: prices, period: fast)
        let emaSlow = calculateEMA(prices: prices, period: slow)

        // EMA结果是从 period-1 位置开始的，所以对齐位置
        let startIndex = slow - 1  // 25

        var dif: [Double?] = Array(repeating: nil, count: startIndex)
        for i in 0..<min(emaFast.count, emaSlow.count) {
            dif.append(emaFast[i] - emaSlow[i])
        }

        let difValues = dif.compactMap { $0 }
        let dea = calculateEMA(prices: difValues, period: signal)

        var deaResult: [Double?] = Array(repeating: nil, count: dif.count - dea.count)
        deaResult.append(contentsOf: dea.map { Optional($0) })

        var histogram: [Double?] = Array(repeating: nil, count: dif.count)
        for i in 0..<min(dif.count, deaResult.count) {
            if let d = dif[i], let deaVal = deaResult[i] {
                histogram[i] = (d - deaVal) * 2
            }
        }

        return MACDData(dif: dif, dea: deaResult, histogram: histogram)
    }

    private func calculateEMA(prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period else { return [] }

        var ema: [Double] = []
        let multiplier = 2.0 / Double(period + 1)

        // 第一个EMA是SMA
        let sma = prices[0..<period].reduce(0, +) / Double(period)
        ema.append(sma)

        for i in period..<prices.count {
            let newEma = (prices[i] - ema.last!) * multiplier + ema.last!
            ema.append(newEma)
        }

        return ema
    }

    // MARK: - KDJ计算

    private func calculateKDJ(data: [KLineData], period: Int = 9) -> KDJData {
        var k: [Double?] = Array(repeating: nil, count: period - 1)
        var d: [Double?] = Array(repeating: nil, count: period - 1)
        var j: [Double?] = Array(repeating: nil, count: period - 1)

        for i in (period - 1)..<data.count {
            let slice = data[(i - period + 1)...i]
            let high = slice.map { $0.high }.max() ?? 0
            let low = slice.map { $0.low }.min() ?? 0
            let close = data[i].close

            let rsv = high == low ? 0.0 : (close - low) / (high - low) * 100

            let prevKVal: Double = (k.last ?? 50.0) ?? 50.0
            let prevDVal: Double = (d.last ?? 50.0) ?? 50.0
            let currentK = (2.0 * prevKVal + rsv) / 3.0
            let currentD = (2.0 * prevDVal + currentK) / 3.0
            let currentJ = 3.0 * currentK - 2.0 * currentD

            k.append(currentK)
            d.append(currentD)
            j.append(currentJ)
        }

        return KDJData(k: k, d: d, j: j)
    }

    // MARK: - RSI计算

    private func calculateRSI(prices: [Double], periods: [Int] = [6, 12, 24]) -> RSIData {
        let rsi6 = calculateRSIImpl(prices: prices, period: 6)
        let rsi12 = calculateRSIImpl(prices: prices, period: 12)
        let rsi24 = calculateRSIImpl(prices: prices, period: 24)
        return RSIData(rsi6: rsi6, rsi12: rsi12, rsi24: rsi24)
    }

    private func calculateRSIImpl(prices: [Double], period: Int) -> [Double?] {
        var result: [Double?] = Array(repeating: nil, count: period)

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
            let rsi = 100 - (100 / (1 + rs))
            result.append(rsi)
        }

        return result
    }

    // MARK: - 布林带计算

    private func calculateBollingerBands(prices: [Double], period: Int = 20, stdDev: Double = 2.0) -> BollingerBandsData {
        let middle = calculateMA(prices: prices, period: period)

        var upper: [Double?] = []
        var lower: [Double?] = []

        for i in 0..<prices.count {
            guard let m = middle[i] else {
                upper.append(nil)
                lower.append(nil)
                continue
            }

            let startIdx = max(0, i - period + 1)
            let slice = Array(prices[startIdx...i])
            let variance = slice.reduce(0) { $0 + pow($1 - m, 2) } / Double(slice.count)
            let std = sqrt(variance)

            upper.append(m + stdDev * std)
            lower.append(m - stdDev * std)
        }

        return BollingerBandsData(upper: upper, middle: middle, lower: lower)
    }

    // MARK: - 辅助方法

    private func stockCodeToName(_ code: String) -> String {
        // Mock实现
        let names: [String: String] = [
            "000001": "平安银行",
            "000002": "万科A",
            "600000": "浦发银行",
            "600519": "贵州茅台",
            "000858": "五粮液"
        ]
        return names[code] ?? code
    }

    // MARK: - 搜索股票

    func searchStocks(keyword: String) -> [StockInfo] {
        // TODO: 调用真实API搜索股票
        return []
    }
}
