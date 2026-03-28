import Foundation

//
//  Stock.swift
//  OpenClawTrader
//
//  功能：股票搜索模型，从 stock_data.json 加载真实数据
//

// ============================================
// MARK: - Stock (搜索用)
// ============================================

struct Stock: Identifiable, Codable, Hashable {
    let id: String
    var symbol: String      // 股票代码，如 "300548"
    var name: String        // 股票名称，如 "长芯博创"
    var currentPrice: Double // 当前价格
    var dayChange: Double   // 今日涨跌额
    var dayChangePercent: Double // 今日涨跌幅 %

    // 从 stock_data.json 加载真实A股数据
    static let realStocks: [Stock] = {
        guard let url = Bundle.main.url(forResource: "stock_data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([StockData].self, from: data) else {
            // 如果加载失败，返回空数组
            return []
        }
        return json.map { item in
            Stock(
                id: "stock_\(item.code)",
                symbol: item.code,
                name: item.name,
                currentPrice: item.price,
                dayChange: item.change,
                dayChangePercent: item.change
            )
        }
    }()

    static let preview = realStocks.first ?? Stock(id: "stock_300548", symbol: "300548", name: "长芯博创", currentPrice: 150.70, dayChange: 1.92, dayChangePercent: 1.30)
}

// JSON 数据结构
private struct StockData: Codable {
    let code: String
    let name: String
    let price: Double
    let change: Double
}
