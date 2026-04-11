import Foundation

//
//  StockMapper.swift
//  OpenClawTrader
//
//  股票代码映射工具
//  对应 Python stock_mapper.py
//  P0: KNOWN_STOCKS 预置库
//  P1: Sina suggest 接口
//

// MARK: - StockMapper

/// 股票代码映射器
struct StockMapper {

    // MARK: - 预置股票库 (P0)

    static let knownStocks: [String: StockInfo] = [
        "永泰能源":    StockInfo(name: "永泰能源",    code: "600157", exchange: "沪A", sector: "煤炭/电力", cap: "中等"),
        "协鑫能科":    StockInfo(name: "协鑫能科",    code: "002015", exchange: "深A", sector: "电力设备/新能源", cap: "中小盘"),
        "皖能电力":    StockInfo(name: "皖能电力",    code: "000543", exchange: "深A", sector: "电力/公用事业", cap: "中大盘"),
        "沃顿科技":    StockInfo(name: "沃顿科技",    code: "301058", exchange: "深A", sector: "专用设备/科技", cap: "小盘"),
        "兆易创新":    StockInfo(name: "兆易创新",    code: "603986", exchange: "沪A", sector: "半导体/芯片", cap: "中等科技"),
        "贵州茅台":    StockInfo(name: "贵州茅台",    code: "600519", exchange: "沪A", sector: "白酒", cap: "大盘蓝筹"),
        "宁德时代":    StockInfo(name: "宁德时代",    code: "300750", exchange: "深A", sector: "新能源电池", cap: "大盘成长"),
        "比亚迪":      StockInfo(name: "比亚迪",      code: "002594", exchange: "深A", sector: "汽车/新能源", cap: "大盘蓝筹"),
        "中国平安":    StockInfo(name: "中国平安",    code: "601318", exchange: "沪A", sector: "金融保险", cap: "大盘蓝筹"),
        "招商银行":    StockInfo(name: "招商银行",    code: "600036", exchange: "沪A", sector: "银行", cap: "大盘蓝筹"),
        "中远海控":    StockInfo(name: "中远海控",    code: "601919", exchange: "沪A", sector: "航运", cap: "中大盘"),
        "阳光电源":    StockInfo(name: "阳光电源",    code: "300274", exchange: "深A", sector: "光伏/新能源", cap: "中等"),
        "隆基绿能":    StockInfo(name: "隆基绿能",    code: "601012", exchange: "沪A", sector: "光伏", cap: "大盘"),
    ]

    // MARK: - 行业/板块映射

    /// 基于代码前缀的行业映射
    static let sectorByCode: [String: String] = [
        "0": "主板/中小板",
        "3": "创业板",
        "6": "沪市主板",
        "8": "北交所",
    ]

    /// 基于代码前缀的市值偏好映射
    static let capPreferenceByCode: [String: String] = [
        "601": "大盘蓝筹",
        "600": "大盘蓝筹",
        "000": "中大盘",
        "002": "中小盘",
        "300": "中小成长",
        "301": "中小成长",
    ]

    // MARK: - 查询方法

    /// 通过名称查找股票信息
    static func findByName(_ name: String) -> StockInfo? {
        return knownStocks[name]
    }

    /// 通过代码查找股票信息
    static func findByCode(_ code: String) -> StockInfo? {
        for stock in knownStocks.values {
            if stock.code == code {
                return stock
            }
        }
        return nil
    }

    /// 通过名称获取代码
    static func codeForName(_ name: String) -> String? {
        return knownStocks[name]?.code
    }

    /// 通过代码获取名称
    static func nameForCode(_ code: String) -> String? {
        return findByCode(code)?.name
    }

    /// 获取交易所
    static func exchangeForCode(_ code: String) -> String {
        if code.hasPrefix("6") {
            return "沪A"
        } else if code.hasPrefix("0") || code.hasPrefix("3") {
            return "深A"
        }
        return "?"
    }

    /// 推断行业
    static func inferSector(for code: String) -> String {
        if let stock = findByCode(code) {
            return stock.sector
        }

        let prefix = String(code.prefix(3))
        if let cap = capPreferenceByCode[prefix] {
            return "\(sectorByCode[String(code.first ?? "0")] ?? "")/\(cap)"
        }

        if code.hasPrefix("6") {
            return "沪市主板"
        } else if code.hasPrefix("0") {
            return "深市主板"
        } else if code.hasPrefix("3") {
            return "创业板/科技"
        }
        return "未知"
    }

    /// 推断市值偏好
    static func inferCapPreference(for code: String) -> String {
        if let stock = findByCode(code) {
            return stock.cap
        }

        let prefix = String(code.prefix(3))
        return capPreferenceByCode[prefix] ?? "?"
    }

    // MARK: - 验证

    /// 验证股票代码格式
    static func isValidCode(_ code: String) -> Bool {
        let pattern = #"^[603]\d{5}$"#
        return code.range(of: pattern, options: .regularExpression) != nil
    }

    /// 验证股票名称
    static func isValidName(_ name: String) -> Bool {
        return name.count >= 2 && name.count <= 6
    }
}

// MARK: - StockInfo

/// 股票详细信息
struct StockInfo {
    var name: String
    var code: String
    var exchange: String
    var sector: String
    var cap: String

    init(name: String = "", code: String = "", exchange: String = "", sector: String = "", cap: String = "") {
        self.name = name
        self.code = code
        self.exchange = exchange
        self.sector = sector
        self.cap = cap
    }

    enum CodingKeys: String, CodingKey {
        case name
        case code
        case exchange
        case sector
        case cap
    }
}

// MARK: - Codable Support

extension StockInfo: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        exchange = try container.decodeIfPresent(String.self, forKey: .exchange) ?? ""
        sector = try container.decodeIfPresent(String.self, forKey: .sector) ?? ""
        cap = try container.decodeIfPresent(String.self, forKey: .cap) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(code, forKey: .code)
        try container.encodeIfPresent(exchange, forKey: .exchange)
        try container.encodeIfPresent(sector, forKey: .sector)
        try container.encodeIfPresent(cap, forKey: .cap)
    }
}

// MARK: - Batch Lookup

extension StockMapper {
    /// 批量查找股票信息
    static func findStocks(matching names: [String]) -> [String: StockInfo] {
        var result: [String: StockInfo] = [:]
        for name in names {
            if let info = findByName(name) {
                result[name] = info
            }
        }
        return result
    }

    /// 批量查找代码
    static func findCodes(matching codes: [String]) -> [String: StockInfo] {
        var result: [String: StockInfo] = [:]
        for code in codes {
            if let info = findByCode(code) {
                result[code] = info
            }
        }
        return result
    }
}
