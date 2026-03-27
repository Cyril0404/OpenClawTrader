import Foundation

//
//  Performance.swift
//  OpenClawTrader
//
//  功能：收益表现数据模型，包含各类收益率统计
//

// ============================================
// MARK: - Performance Report
// ============================================

struct PerformanceReport: Codable {
    var totalReturn: Double
    var totalReturnPercent: Double
    var dayReturn: Double
    var dayReturnPercent: Double
    var weekReturn: Double
    var weekReturnPercent: Double
    var monthReturn: Double
    var monthReturnPercent: Double
    var yearReturn: Double
    var yearReturnPercent: Double
    var vsBenchmark: Double
    var vsBenchmarkPercent: Double
    var winRate: Double
    var totalTrades: Int
    var winningTrades: Int
    var losingTrades: Int
    var averageWin: Double
    var averageLoss: Double
    var profitFactor: Double
    var maxDrawdown: Double
    var maxDrawdownPercent: Double
    var sharpeRatio: Double

    static let preview = PerformanceReport(
        totalReturn: 134560.00,
        totalReturnPercent: 11.70,
        dayReturn: 12450.00,
        dayReturnPercent: 0.98,
        weekReturn: 28500.00,
        weekReturnPercent: 2.27,
        monthReturn: 89200.00,
        monthReturnPercent: 7.45,
        yearReturn: 134560.00,
        yearReturnPercent: 11.70,
        vsBenchmark: 3.20,
        vsBenchmarkPercent: 3.20,
        winRate: 0.62,
        totalTrades: 127,
        winningTrades: 79,
        losingTrades: 48,
        averageWin: 3200.00,
        averageLoss: 1850.00,
        profitFactor: 1.73,
        maxDrawdown: 28500.00,
        maxDrawdownPercent: -2.18,
        sharpeRatio: 1.45
    )
}

// ============================================
// MARK: - Performance Data Point
// ============================================

struct PerformanceDataPoint: Identifiable, Codable {
    let id: String
    var date: Date
    var portfolioValue: Double
    var benchmarkValue: Double?

    static func generatePreviewData(days: Int) -> [PerformanceDataPoint] {
        var data: [PerformanceDataPoint] = []
        var portfolioValue = 1000000.0
        var benchmarkValue = 1000000.0

        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -days + i, to: Date())!
            portfolioValue *= Double.random(in: 0.98...1.02)
            benchmarkValue *= Double.random(in: 0.99...1.01)

            data.append(PerformanceDataPoint(
                id: "dp_\(i)",
                date: date,
                portfolioValue: portfolioValue,
                benchmarkValue: benchmarkValue
            ))
        }

        return data
    }
}
