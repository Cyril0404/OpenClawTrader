import Foundation

//
//  StockChart.swift
//  OpenClawTrader
//
//  功能：股票行情数据模型
//

// ============================================
// MARK: - K线数据
// ============================================

struct KLineData: Identifiable, Codable {
    let id: UUID
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    init(id: UUID = UUID(), date: Date, open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.id = id
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    var isBullish: Bool {
        close >= open
    }

    var bodyHeight: Double {
        abs(close - open)
    }

    var upperWick: Double {
        high - max(open, close)
    }

    var lowerWick: Double {
        min(open, close) - low
    }
}

// ============================================
// MARK: - 技术指标
// ============================================

struct TechnicalIndicators: Codable {
    let ma5: [Double?]   // 5日均线
    let ma10: [Double?]  // 10日均线
    let ma20: [Double?]  // 20日均线
    let ma60: [Double?]  // 60日均线

    let macd: MACDData?
    let kdj: KDJData?
    let rsi: RSIData?
    let boll: BollingerBandsData?

    static var empty: TechnicalIndicators {
        TechnicalIndicators(
            ma5: [], ma10: [], ma20: [], ma60: [],
            macd: nil, kdj: nil, rsi: nil, boll: nil
        )
    }
}

struct MACDData: Codable {
    let dif: [Double?]
    let dea: [Double?]
    let histogram: [Double?]
}

struct KDJData: Codable {
    let k: [Double?]
    let d: [Double?]
    let j: [Double?]
}

struct RSIData: Codable {
    let rsi6: [Double?]   // 6日RSI
    let rsi12: [Double?]  // 12日RSI
    let rsi24: [Double?]  // 24日RSI
}

struct BollingerBandsData: Codable {
    let upper: [Double?]  // 上轨
    let middle: [Double?] // 中轨（20日均线）
    let lower: [Double?]  // 下轨
}

// ============================================
// MARK: - 股票信息
// ============================================

struct StockInfo: Identifiable, Codable {
    let id: String  // 股票代码
    let name: String
    let market: String  // 上交所、深交所、北交所

    static var preview: StockInfo {
        StockInfo(id: "000001", name: "平安银行", market: "深交所")
    }
}

// ============================================
// MARK: - K线周期
// ============================================

enum KLinePeriod: String, CaseIterable, Identifiable {
    case daily = "日线"
    case weekly = "周线"
    case monthly = "月线"
    case quarterly = "季线"

    var id: String { rawValue }
}

// ============================================
// MARK: - 技术指标类型
// ============================================

enum IndicatorType: String, CaseIterable, Identifiable {
    case ma = "均线"
    case macd = "MACD"
    case kdj = "KDJ"
    case rsi = "RSI"
    case boll = "布林带"

    var id: String { rawValue }
}

// ============================================
// MARK: - Mock 数据
// ============================================

extension KLineData {
    static func mockData(days: Int = 60) -> [KLineData] {
        var data: [KLineData] = []
        var basePrice = 15.0
        let calendar = Calendar.current

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -days + i, to: Date())!
            let change = Double.random(in: -0.05...0.05)
            let open = basePrice
            let close = open * (1 + change)
            let high = max(open, close) * (1 + Double.random(in: 0...0.02))
            let low = min(open, close) * (1 - Double.random(in: 0...0.02))
            let volume = Double.random(in: 1_000_000...10_000_000)

            data.append(KLineData(
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            ))

            basePrice = close
        }

        return data
    }
}
