import Foundation

//
//  Trade.swift
//  OpenClawTrader
//
//  交易记录数据模型
//  对应 Python analyze.py 的 parse_ocr_text() 输出
//

// MARK: - Trade

/// 交易记录模型
struct Trade: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString

    /// 股票名称 如"永泰能源"
    var stockName: String

    /// 股票代码 如"600157"
    var stockCode: String

    /// 交易所 如"沪A"/"深A"
    var exchange: String

    /// 交易时间 如"20260330 09:32:11"
    var datetime: String

    /// 买卖方向 "买入" / "卖出"
    var direction: String

    /// 订单状态 "已成" / "已撤" / "废单"
    var status: String

    /// 委托价格
    var entrustPrice: Double?

    /// 成交价格
    var dealPrice: Double?

    /// 委托数量
    var entrustQty: Double?

    /// 成交数量
    var dealQty: Double?

    /// 成交金额 = dealPrice * dealQty
    var amount: Double?

    /// 记录添加时间
    var addedAt: String

    /// 画像版本（用于追踪）
    var profileVersion: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case stockName = "stock_name"
        case stockCode = "stock_code"
        case exchange
        case datetime
        case direction
        case status
        case entrustPrice = "entrust_price"
        case dealPrice = "deal_price"
        case entrustQty = "entrust_qty"
        case dealQty = "deal_qty"
        case amount
        case addedAt = "added_at"
        case profileVersion = "profile_version"
    }

    init(
        id: String = UUID().uuidString,
        stockName: String,
        stockCode: String,
        exchange: String = "",
        datetime: String,
        direction: String,
        status: String,
        entrustPrice: Double? = nil,
        dealPrice: Double? = nil,
        entrustQty: Double? = nil,
        dealQty: Double? = nil,
        amount: Double? = nil,
        addedAt: String = ISO8601DateFormatter().string(from: Date()),
        profileVersion: Int? = nil
    ) {
        self.id = id
        self.stockName = stockName
        self.stockCode = stockCode
        self.exchange = exchange.isEmpty ? (stockCode.hasPrefix("6") ? "沪A" : "深A") : exchange
        self.datetime = datetime
        self.direction = direction
        self.status = status
        self.entrustPrice = entrustPrice
        self.dealPrice = dealPrice
        self.entrustQty = entrustQty
        self.dealQty = dealQty
        self.amount = amount
        self.addedAt = addedAt
        self.profileVersion = profileVersion
    }

    /// 计算成交金额
    var calculatedAmount: Double? {
        if let amount = amount { return amount }
        if let price = dealPrice ?? entrustPrice,
           let qty = dealQty ?? entrustQty {
            return price * qty
        }
        return nil
    }

    /// 是否是已成交易
    var isCompleted: Bool {
        status == "已成"
    }

    /// 是否是买入
    var isBuy: Bool {
        direction == "买入"
    }

    /// 是否是卖出
    var isSell: Bool {
        direction == "卖出"
    }

    /// 是否已撤销
    var isCancelled: Bool {
        status == "已撤" || status == "废单"
    }
}

// MARK: - Trade Validation

extension Trade {
    /// 七字段校验
    static func validate(_ trade: Trade) -> TradeValidationResult {
        var issues: [String] = []

        // datetime 格式校验
        if trade.datetime.isEmpty {
            issues.append("时间不能为空")
        } else if !isValidDateTimeFormat(trade.datetime) {
            issues.append("时间格式异常")
        }

        // stockName 校验
        if trade.stockName.isEmpty {
            issues.append("股票名称不能为空")
        } else if trade.stockName.count < 2 || trade.stockName.count > 6 {
            issues.append("股票名称长度异常")
        }

        // stockCode 校验
        if trade.stockCode.isEmpty {
            issues.append("股票代码不能为空")
        } else if !isValidStockCode(trade.stockCode) {
            issues.append("股票代码格式异常")
        }

        // direction 校验
        if trade.direction != "买入" && trade.direction != "卖出" {
            issues.append("买卖方向异常")
        }

        // status 校验
        if trade.status != "已成" && trade.status != "已撤" && trade.status != "废单" {
            issues.append("状态异常")
        }

        // price 校验
        if let price = trade.entrustPrice ?? trade.dealPrice {
            if price <= 0 {
                issues.append("价格必须大于0")
            }
        } else {
            issues.append("价格缺失")
        }

        // quantity 校验
        if let qty = trade.entrustQty ?? trade.dealQty {
            if qty <= 0 {
                issues.append("数量必须大于0")
            }
        } else {
            issues.append("数量缺失")
        }

        return TradeValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }

    private static func isValidDateTimeFormat(_ str: String) -> Bool {
        let pattern = #"^\d{8}\s+\d{2}:\d{2}:\d{2}$"#
        return str.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isValidStockCode(_ str: String) -> Bool {
        let pattern = #"^\d{6}$"#
        return str.range(of: pattern, options: .regularExpression) != nil
    }
}

struct TradeValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Trade Extensions

extension Trade {
    /// 从文本解析创建（简化版）
    static func parse(from text: String, stockCode: String = "", exchange: String = "") -> Trade? {
        let components = text.split(separator: " ").map(String.init)
        guard components.count >= 2 else { return nil }

        return Trade(
            stockName: components[0],
            stockCode: stockCode,
            exchange: exchange,
            datetime: "",
            direction: "",
            status: ""
        )
    }
}
