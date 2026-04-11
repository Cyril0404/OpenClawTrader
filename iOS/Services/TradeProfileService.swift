import Foundation

//
//  TradeProfileService.swift
//  OpenClawTrader
//
//  用户画像核心服务
//  对应 Python profile_manager.py + holdings_init.py
//

// MARK: - TradeProfileService

/// 用户画像服务
class TradeProfileService {
    static let shared = TradeProfileService()

    private let dataPath: URL
    private let profileVersion = "2.0"

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dataPath = documentsPath.appendingPathComponent("user_trades.json")
    }

    // MARK: - Data Storage

    private func readData() -> TradeData {
        guard FileManager.default.fileExists(atPath: dataPath.path) else {
            return TradeData.empty()
        }
        do {
            let data = try Data(contentsOf: dataPath)
            let decoder = JSONDecoder()
            return try decoder.decode(TradeData.self, from: data)
        } catch {
            print("读取数据失败: \(error)")
            return TradeData.empty()
        }
    }

    private func writeData(_ data: TradeData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: dataPath, options: .atomic)
        } catch {
            print("写入数据失败: \(error)")
        }
    }

    // MARK: - Trade Management

    /// 添加交易记录（去重追加）
    func addTrades(_ newTrades: [Trade]) -> Int {
        var data = readData()

        // 构建已有去重键
        var existingKeys = Set<String>()
        var existingMap: [String: Trade] = [:]

        for t in data.trades {
            let key = tradeKey(t)
            existingKeys.insert(key)
            existingMap[key] = t
        }

        var added = 0
        for trade in newTrades {
            let key = tradeKey(trade)
            let newStatus = trade.status
            let existing = existingMap[key]

            if existingKeys.contains(key), let existing = existing {
                // 已有记录：已撤/废单 -> 已成 替换
                if (existing.status == "已撤" || existing.status == "废单") && newStatus == "已成" {
                    if let idx = data.trades.firstIndex(where: { tradeKey($0) == key }) {
                        data.trades.remove(at: idx)
                    }
                    var updatedTrade = trade
                    updatedTrade.profileVersion = (data.profileVersion ?? 0) + 1
                    data.trades.append(updatedTrade)
                    added += 1
                }
            } else {
                // 新记录
                var newTrade = trade
                newTrade.profileVersion = (data.profileVersion ?? 0) + 1
                data.trades.append(newTrade)
                existingKeys.insert(key)
                existingMap[key] = newTrade
                added += 1
            }
        }

        data.lastUpdated = ISO8601DateFormatter().string(from: Date())
        data.profileVersion = (data.profileVersion ?? 0) + 1
        writeData(data)

        return added
    }

    private func tradeKey(_ trade: Trade) -> String {
        // 包含 entrustPrice 和 dealPrice，避免部分成交的限价单被错误去重
        let price = trade.dealPrice ?? trade.entrustPrice ?? 0
        return "\(trade.datetime)|\(trade.stockName)|\(trade.direction)|\(price)"
    }

    /// 获取所有交易记录
    func getAllTrades() -> [Trade] {
        let data = readData()
        return data.trades.sorted { $0.datetime < $1.datetime }
    }

    /// 获取已成交易
    func getCompletedTrades() -> [Trade] {
        getAllTrades().filter { $0.status == "已成" }
    }

    /// 清空所有交易
    func clearAllTrades() {
        var data = readData()
        data.trades = []
        data.profileVersion = 0
        data.profileSummary = nil
        writeData(data)
    }

    // MARK: - Holdings Management

    /// 获取持仓
    func getHoldings() -> HoldingsResult {
        let data = readData()
        return HoldingsResult(
            holdings: data.holdings,
            initialized: data.holdingsInitialized ?? false,
            note: data.holdingsNote ?? "",
            lastUpdated: data.holdingsLastUpdated
        )
    }

    /// 初始化持仓
    func initHoldings(_ holdings: [Holding], source: String = "用户手动输入") -> HoldingsInitResult {
        var data = readData()

        var normalized: [Holding] = []
        var warnings: [String] = []

        for (i, h) in holdings.enumerated() {
            guard !h.name.isEmpty else {
                warnings.append("第\(i+1)条缺少股票名称，已跳过")
                continue
            }

            var code = h.code
            if code.isEmpty {
                code = StockMapper.codeForName(h.name) ?? ""
                if code.isEmpty {
                    warnings.append("无法识别 [\(h.name)] 的代码，已跳过")
                    continue
                }
            }

            guard h.quantity > 0 else {
                warnings.append("[\(h.name)] 数量异常(<=0)，已跳过")
                continue
            }

            let exchange = h.exchange.isEmpty ? StockMapper.exchangeForCode(code) : h.exchange

            normalized.append(Holding(
                id: h.id.isEmpty ? UUID().uuidString : h.id,
                name: h.name,
                code: code,
                exchange: exchange,
                quantity: h.quantity,
                source: source,
                addedAt: ISO8601DateFormatter().string(from: Date())
            ))
        }

        guard !normalized.isEmpty else {
            return HoldingsInitResult(
                success: false,
                holdings: [],
                warnings: warnings,
                error: "没有有效持仓数据"
            )
        }

        data.holdings = normalized
        data.holdingsInitialized = true
        data.holdingsSource = source
        data.holdingsLastUpdated = ISO8601DateFormatter().string(from: Date())
        data.holdingsNote = "⚠️ 此为\(source)数据，完整持仓需用户提供全部历史记录。持仓数据影响个性化投资建议的精准度。"
        writeData(data)

        return HoldingsInitResult(
            success: true,
            holdings: normalized,
            warnings: warnings,
            savedAt: data.holdingsLastUpdated
        )
    }

    /// 从委托单推算持仓
    func inferHoldings() -> [InferredHolding] {
        let trades = getCompletedTrades()

        var stockBuys: [String: Int] = [:]
        var stockSells: [String: Int] = [:]
        var stockInfo: [String: (code: String, exchange: String)] = [:]

        for t in trades {
            let name = t.stockName
            let qty = Int(t.dealQty ?? t.entrustQty ?? 0)
            guard qty > 0 else { continue }

            var code = t.stockCode
            if code.isEmpty {
                code = StockMapper.codeForName(name) ?? ""
            }

            let exchange = t.exchange.isEmpty ? StockMapper.exchangeForCode(code) : t.exchange
            stockInfo[name] = (code, exchange)

            if t.direction == "买入" {
                stockBuys[name, default: 0] += qty
            } else if t.direction == "卖出" {
                stockSells[name, default: 0] += qty
            }
        }

        var holdings: [InferredHolding] = []
        for (name, buyQty) in stockBuys {
            let sellQty = stockSells[name, default: 0]
            let netQty = buyQty - sellQty

            if netQty > 0 {
                let info = stockInfo[name] ?? ("?", "?")
                holdings.append(InferredHolding(
                    name: name,
                    code: info.code,
                    exchange: info.exchange,
                    quantity: netQty,
                    source: "委托单推算",
                    note: "买入\(buyQty)股 - 卖出\(sellQty)股 = 推定持有\(netQty)股"
                ))
            }
        }

        return holdings
    }

    /// 保存推算持仓
    func saveInferredHoldings() -> HoldingsInitResult {
        let inferred = inferHoldings()
        guard !inferred.isEmpty else {
            return HoldingsInitResult(
                success: false,
                holdings: [],
                warnings: [],
                message: "从委托单推算无持仓（可能全部已卖出）"
            )
        }

        let holdings = inferred.map { i in
            Holding(id: UUID().uuidString, name: i.name, code: i.code, exchange: i.exchange, quantity: i.quantity)
        }

        let result = initHoldings(holdings, source: "委托单推算")
        return HoldingsInitResult(
            success: result.success,
            holdings: result.holdings,
            warnings: result.warnings,
            message: "从\(getAllTrades().count)条委托单推算到\(inferred.count)只持仓",
            savedAt: result.savedAt
        )
    }

    // MARK: - Profile Generation (三审机制)

    /// 生成用户画像
    func generateProfile() -> UserProfile {
        let trades = getAllTrades()

        guard !trades.isEmpty else {
            return UserProfile.insufficientData()
        }

        // 初审：数据质量核查
        let audit = auditData(trades)

        // 过滤废单
        let validTrades = trades.filter { $0.status == "已成" }
        let allDoneTrades = trades.filter { $0.status == "已成" || $0.status == "已撤" }

        guard !validTrades.isEmpty else {
            return UserProfile.insufficientData()
        }

        // 二审：模式识别
        let stats = computeStats(trades, validTrades: validTrades, allDone: allDoneTrades)
        let holding = analyzeHoldingPeriod(trades)
        let (style, styleConf) = analyzeStyle(trades, validTrades: validTrades, holding: holding)
        let pnl = estimatePnL(trades, validTrades: validTrades)
        let sector = analyzeSector(trades)
        let timing = analyzeTiming(trades, validTrades: validTrades)

        // 三审：结论生成
        let warnings = generateWarnings(trades, validTrades: validTrades, stats: stats, holding: holding)
        let insights = generateInsights(trades, validTrades: validTrades, stats: stats, holding: holding, style: style, pnl: pnl, sector: sector, timing: timing)
        let personality = generatePersonalityTags(trades, validTrades: validTrades, holding: holding, stats: stats, pnl: pnl, timing: timing)
        let radar = generateRadar(trades, validTrades: validTrades, stats: stats, holding: holding, pnl: pnl)
        let advice = generateAdvice(trades, validTrades: validTrades, stats: stats, holding: holding, pnl: pnl, sector: sector, personality: personality, behaviorInsights: insights)

        // 一句话定位
        let primaryTags = personality.primary
        let isAggressive = primaryTags.contains(where: { ["快进快出型", "超短线（≤1天）", "题材猎手"].contains($0) })
        let oneLiner = "你是\(primaryTags.prefix(2).joined(separator: " + "))投资者，风格\(isAggressive ? "激进" : "稳健")，执行力\(stats.cancelRate > 0.2 ? "有提升空间" : "良好")。"

        var profile = UserProfile()
        profile.audit = audit
        profile.totalTrades = trades.count
        profile.doneTrades = validTrades.count
        profile.cancelCount = stats.cancelCount
        profile.cancelRate = stats.cancelRate
        profile.completionRate = stats.completionRate
        profile.buyCount = stats.buyCount
        profile.sellCount = stats.sellCount
        profile.directionRatio = stats.directionRatio
        profile.style = style
        profile.styleConfidence = styleConf
        profile.avgHoldingDays = holding.avgHoldingDays
        profile.holdingDistribution = holding.distribution
        profile.winRate = pnl.winRate
        profile.estimatedProfit = pnl.estimatedProfit
        profile.estimatedLoss = pnl.estimatedLoss
        profile.profitLossRatio = pnl.profitLossRatio
        profile.netPnl = pnl.netPnl
        profile.sectorPreference = sector.sectorPreference
        profile.sectorDetail = sector.sectorDetail
        profile.marketCapPreference = sector.marketCapPreference
        profile.timingPattern = timing.pattern
        profile.chasingScore = timing.chasingScore
        profile.bottomFishingScore = timing.bottomFishingScore
        profile.timingConfidence = timing.confidence
        profile.topStocks = stats.topStocks
        profile.stockDetail = sector.stockDetail
        profile.riskWarnings = warnings
        profile.insights = insights
        profile.confidence = stats.total >= 10 ? "高" : (stats.total >= 5 ? "中" : "低")
        profile.riskLevel = computeRiskLevel(validTrades: validTrades, stats: stats, warnings: warnings)
        profile.oneLiner = oneLiner
        profile.personalityTags = personality
        profile.capabilityRadar = radar
        profile.behaviorInsights = insights
        profile.personalizedAdvice = advice
        profile.disclaimer = "能力评分仅供参考，不构成投资能力背书。盈利与能力相关但不等同，市场环境运气因素均影响结果。"
        profile.generatedAt = ISO8601DateFormatter().string(from: Date())

        // 保存画像
        var data = readData()
        data.profileSummary = profile
        writeData(data)

        return profile
    }

    /// 获取已保存的画像
    func getProfile() -> UserProfile? {
        readData().profileSummary
    }

    // MARK: - 初审：数据质量核查

    private func auditData(_ trades: [Trade]) -> AuditResult {
        var issues: [String] = []

        let requiredFields = ["datetime", "stockName", "direction", "status"]
        for (i, t) in trades.enumerated() {
            if t.datetime.isEmpty { issues.append("第\(i+1)条缺少时间") }
            if t.stockName.isEmpty { issues.append("第\(i+1)条缺少股票名称") }
            if t.direction.isEmpty { issues.append("第\(i+1)条缺少方向") }
            if t.status.isEmpty { issues.append("第\(i+1)条缺少状态") }
        }

        for t in trades {
            if let price = t.entrustPrice ?? t.dealPrice, price <= 0 {
                issues.append("\(t.stockName) 价格异常")
            }
            if let qty = t.entrustQty ?? t.dealQty, qty <= 0 {
                issues.append("\(t.stockName) 数量异常")
            }
        }

        return AuditResult(
            passed: issues.isEmpty,
            issues: Array(issues.prefix(10)),
            totalIssues: issues.count
        )
    }

    // MARK: - 二审辅助

    private struct StatsResult {
        var total: Int
        var buyCount: Int
        var sellCount: Int
        var cancelCount: Int
        var doneCount: Int
        var cancelRate: Double
        var completionRate: Double
        var directionRatio: [String: Double]
        var totalBuyAmount: Double
        var totalSellAmount: Double
        var topStocks: [String]
        var stockCounts: [String: Int]
    }

    private func computeStats(_ trades: [Trade], validTrades: [Trade], allDone: [Trade]) -> StatsResult {
        let total = trades.count
        let buyCount = trades.filter { $0.direction == "买入" }.count
        let sellCount = trades.filter { $0.direction == "卖出" }.count
        let cancelCount = trades.filter { $0.status == "已撤" || $0.status == "废单" }.count
        let doneCount = validTrades.count

        let cancelRate = total > 0 ? Double(cancelCount) / Double(total) : 0
        let completionRate = total > 0 ? Double(doneCount) / Double(total) : 0

        var stockCounts: [String: Int] = [:]
        for t in trades {
            stockCounts[t.stockName, default: 0] += 1
        }
        let topStocks = stockCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }

        return StatsResult(
            total: total,
            buyCount: buyCount,
            sellCount: sellCount,
            cancelCount: cancelCount,
            doneCount: doneCount,
            cancelRate: cancelRate,
            completionRate: completionRate,
            directionRatio: [
                "买入": total > 0 ? Double(buyCount) / Double(total) : 0,
                "卖出": total > 0 ? Double(sellCount) / Double(total) : 0
            ],
            totalBuyAmount: validTrades.filter { $0.direction == "买入" }.compactMap { $0.calculatedAmount }.reduce(0, +),
            totalSellAmount: validTrades.filter { $0.direction == "卖出" }.compactMap { $0.calculatedAmount }.reduce(0, +),
            topStocks: topStocks,
            stockCounts: stockCounts
        )
    }

    // MARK: - 持股周期分析

    private struct HoldingResult {
        var avgHoldingDays: Double
        var distribution: [String: Int]
        var method: String
        var holdingDaysList: [Int]
        var roundTrips: Int
    }

    private func analyzeHoldingPeriod(_ trades: [Trade]) -> HoldingResult {
        let done = trades.filter { $0.status == "已成" }.sorted { $0.datetime < $1.datetime }

        guard !done.isEmpty else {
            return HoldingResult(avgHoldingDays: 0, distribution: [:], method: "insufficient_data", holdingDaysList: [], roundTrips: 0)
        }

        var byStock: [String: [Trade]] = [:]
        for t in done {
            byStock[t.stockName, default: []].append(t)
        }

        var holdingDaysList: [Int] = []

        for (_, stockTrades) in byStock {
            let sorted = stockTrades.sorted { $0.datetime < $1.datetime }
            var position = 0
            var buyTime: String?

            for t in sorted {
                let qty = Int(t.dealQty ?? t.entrustQty ?? 0)
                guard qty > 0 else { continue }

                if t.direction == "买入" {
                    if position == 0 {
                        buyTime = String(t.datetime.prefix(8))
                        position = qty
                    } else {
                        position += qty
                    }
                } else if t.direction == "卖出" && position > 0 {
                    let sellTime = String(t.datetime.prefix(8))
                    if let bt = buyTime {
                        if let buyDate = parseDate(bt), let sellDate = parseDate(sellTime) {
                            let days = Calendar.current.dateComponents([.day], from: buyDate, to: sellDate).day ?? 0
                            holdingDaysList.append(max(days, 0))
                        }
                    }
                    position = max(0, position - qty)
                    if position == 0 { buyTime = nil }
                }
            }
        }

        guard !holdingDaysList.isEmpty else {
            return HoldingResult(avgHoldingDays: 0, distribution: [:], method: "no_complete_round_trip", holdingDaysList: [], roundTrips: 0)
        }

        let avg = Double(holdingDaysList.reduce(0, +)) / Double(holdingDaysList.count)

        var dist: [String: Int] = ["0-1天": 0, "2-5天": 0, "6-15天": 0, "16-30天": 0, "30天+": 0]
        for h in holdingDaysList {
            switch h {
            case 0...1: dist["0-1天", default: 0] += 1
            case 2...5: dist["2-5天", default: 0] += 1
            case 6...15: dist["6-15天", default: 0] += 1
            case 16...30: dist["16-30天", default: 0] += 1
            default: dist["30天+", default: 0] += 1
            }
        }

        return HoldingResult(avgHoldingDays: avg, distribution: dist, method: "round_trip_timing", holdingDaysList: holdingDaysList, roundTrips: holdingDaysList.count)
    }

    private func parseDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: str)
    }

    // MARK: - 风格判断

    private func analyzeStyle(_ trades: [Trade], validTrades: [Trade], holding: HoldingResult) -> (String, String) {
        let avgDays = holding.avgHoldingDays
        let method = holding.method

        let baseStyle: String
        if avgDays <= 1.5 {
            baseStyle = "超短线（日内/隔夜）"
        } else if avgDays <= 5 {
            baseStyle = "短线"
        } else if avgDays <= 20 {
            baseStyle = "中线"
        } else {
            baseStyle = "长线"
        }

        var confidenceFactors: [String] = []
        if method == "round_trip_timing" {
            confidenceFactors.append("基于完整买卖周期")
        } else {
            confidenceFactors.append("基于交易频率估算")
        }

        var stockCounts: [String: Int] = [:]
        for t in validTrades {
            stockCounts[t.stockName, default: 0] += 1
        }

        let repeatStocks = stockCounts.filter { $0.value >= 3 }
        if repeatStocks.count >= 2 {
            confidenceFactors.append("\(repeatStocks.count)只股票反复操作")
        } else if repeatStocks.count == 1 {
            confidenceFactors.append("1只股票反复操作")
        } else {
            confidenceFactors.append("操作分散")
        }

        let cancelRate = trades.filter { $0.status == "已撤" || $0.status == "废单" }.count
        let cancelRatio = trades.isEmpty ? 0 : Double(cancelRate) / Double(trades.count)
        if cancelRatio > 0.25 {
            confidenceFactors.append("撤单率偏高")
        } else if cancelRatio < 0.1 {
            confidenceFactors.append("撤单率低，执行果断")
        }

        let style = baseStyle + (repeatStocks.count >= 1 ? "（单股重复操作）" : "")
        let confidence = confidenceFactors.joined(separator: " / ")

        return (style, confidence)
    }

    // MARK: - 盈亏估算

    private struct PnLResult {
        var winRate: Double
        var estimatedProfit: String
        var estimatedLoss: String
        var profitLossRatio: String
        var netPnl: Double
        var winCount: Int
        var lossCount: Int
        var detail: [PnLDetail]
        // 用于计算的数值字段
        var profitValue: Double
        var lossValue: Double
    }

    private struct PnLDetail {
        var stock: String
        var sellPrice: Double
        var cost: Double
        var qty: Int
        var pnl: Double
        var pnlPct: Double
    }

    private func estimatePnL(_ trades: [Trade], validTrades: [Trade]) -> PnLResult {
        var byStock: [String: [Trade]] = [:]
        for t in validTrades {
            byStock[t.stockName, default: []].append(t)
        }

        var estimatedProfit = 0.0
        var estimatedLoss = 0.0
        var winCount = 0
        var lossCount = 0
        var details: [PnLDetail] = []

        for (_, stockTrades) in byStock {
            let sorted = stockTrades.sorted { $0.datetime < $1.datetime }
            var position = 0
            var avgCost = 0.0

            for t in sorted {
                let qty = Int(t.dealQty ?? t.entrustQty ?? 0)
                let price = t.dealPrice ?? t.entrustPrice ?? 0
                guard qty > 0 && price > 0 else { continue }

                if t.direction == "买入" {
                    if position == 0 {
                        avgCost = price
                        position = qty
                    } else {
                        let totalCost = avgCost * Double(position) + price * Double(qty)
                        position += qty
                        avgCost = totalCost / Double(position)
                    }
                } else if t.direction == "卖出" && position > 0 {
                    let sellQty = min(qty, position)
                    let pnlPerShare = price - avgCost
                    let pnl = pnlPerShare * Double(sellQty)
                    details.append(PnLDetail(
                        stock: t.stockName,
                        sellPrice: price,
                        cost: avgCost,
                        qty: sellQty,
                        pnl: pnl,
                        pnlPct: avgCost > 0 ? pnlPerShare / avgCost * 100 : 0
                    ))

                    if pnl >= 0 {
                        estimatedProfit += pnl
                        winCount += 1
                    } else {
                        estimatedLoss += abs(pnl)
                        lossCount += 1
                    }
                    position -= sellQty
                    if position == 0 { avgCost = 0 }
                }
            }
        }

        let totalTrades = winCount + lossCount
        let winRate = totalTrades > 0 ? Double(winCount) / Double(totalTrades) : 0
        let ratio = estimatedLoss > 0 ? estimatedProfit / estimatedLoss : 0

        return PnLResult(
            winRate: winRate,
            estimatedProfit: estimatedProfit >= 0 ? "+\(String(format: "%.2f", estimatedProfit))元" : "\(String(format: "%.2f", estimatedProfit))元",
            estimatedLoss: "-\(String(format: "%.2f", estimatedLoss))元",
            profitLossRatio: ratio > 0 ? "\(String(format: "%.1f", ratio)):1" : "N/A",
            netPnl: estimatedProfit - estimatedLoss,
            winCount: winCount,
            lossCount: lossCount,
            detail: Array(details.prefix(5)),
            profitValue: estimatedProfit,
            lossValue: estimatedLoss
        )
    }

    // MARK: - 板块偏好

    private struct SectorResult {
        var sectorPreference: String
        var sectorDetail: [String: Int]
        var marketCapPreference: String
        var stockDetail: [String: StockInfo]
        var totalUniqueStocks: Int
    }

    private func analyzeSector(_ trades: [Trade]) -> SectorResult {
        var stockCounts: [String: Int] = [:]
        var uniqueStocks: [String: StockInfo] = [:]

        for t in trades {
            let name = t.stockName
            stockCounts[name, default: 0] += 1

            if uniqueStocks[name] == nil {
                var code = t.stockCode
                if code.isEmpty { code = StockMapper.codeForName(name) ?? "" }

                let sector = StockMapper.inferSector(for: code)
                let cap = StockMapper.inferCapPreference(for: code)
                let exchange = t.exchange.isEmpty ? StockMapper.exchangeForCode(code) : t.exchange

                uniqueStocks[name] = StockInfo(name: name, code: code, exchange: exchange, sector: sector, cap: cap)
            }
        }

        var sectorCount: [String: Int] = [:]
        for (name, info) in uniqueStocks {
            sectorCount[info.sector, default: 0] += stockCounts[name] ?? 1
        }

        let topSectors = sectorCount.sorted { $0.value > $1.value }.prefix(3)
        let sectorPreference = topSectors.map { $0.key }.joined(separator: " / ")
        let sectorDetail = Dictionary(uniqueKeysWithValues: topSectors.map { ($0.key, $0.value) })

        var capCount: [String: Int] = [:]
        for info in uniqueStocks.values {
            capCount[info.cap, default: 0] += 1
        }
        let topCap = capCount.max { $0.value < $1.value } ?? ("?", 0)
        let marketCapPreference = "\(topCap.key)（出现\(topCap.value)次）"

        return SectorResult(
            sectorPreference: sectorPreference.isEmpty ? "数据不足" : sectorPreference,
            sectorDetail: sectorDetail,
            marketCapPreference: marketCapPreference,
            stockDetail: uniqueStocks,
            totalUniqueStocks: uniqueStocks.count
        )
    }

    // MARK: - 时机分析

    private struct TimingResult {
        var pattern: String
        var chasingScore: String
        var bottomFishingScore: String
        var confidence: String
    }

    private func analyzeTiming(_ trades: [Trade], validTrades: [Trade]) -> TimingResult {
        var hourBuy: [Int: Int] = [:]
        var hourSell: [Int: Int] = [:]

        for t in validTrades {
            guard t.datetime.count >= 11 else { continue }
            let hourStr = String(t.datetime.dropFirst(11).prefix(2))
            guard let hour = Int(hourStr) else { continue }

            if t.direction == "买入" {
                hourBuy[hour, default: 0] += 1
            } else if t.direction == "卖出" {
                hourSell[hour, default: 0] += 1
            }
        }

        let openBuy = (hourBuy[9] ?? 0) + (hourBuy[10] ?? 0)
        let closeBuy = (hourBuy[14] ?? 0) + (hourBuy[15] ?? 0)
        let openSell = (hourSell[9] ?? 0) + (hourSell[10] ?? 0)
        let closeSell = (hourSell[14] ?? 0) + (hourSell[15] ?? 0)

        var chasingCount = 0
        var bottomCount = 0

        for t in validTrades {
            let entrustP = t.entrustPrice ?? 0
            let dealP = t.dealPrice ?? 0
            guard entrustP > 0 && dealP > 0 else { continue }

            let slippage = (entrustP - dealP) / entrustP * 100
            if t.direction == "买入" {
                if slippage < -0.5 { bottomCount += 1 }
                else if slippage > 0.5 { chasingCount += 1 }
            }
        }

        let chasingScore = validTrades.isEmpty ? "0%" : "\(Int(Double(chasingCount) / Double(max(validTrades.count / 2, 1)) * 100))%"
        let bottomScore = validTrades.isEmpty ? "0%" : "\(Int(Double(bottomCount) / Double(max(validTrades.count / 2, 1)) * 100))%"

        let pattern: String
        if chasingCount > validTrades.count / 3 && bottomCount < validTrades.count / 10 {
            pattern = "追涨型（倾向于追入强势股）"
        } else if bottomCount > validTrades.count / 3 && chasingCount < validTrades.count / 10 {
            pattern = "抄底型（倾向于左侧买入）"
        } else if chasingCount > validTrades.count / 5 && bottomCount > validTrades.count / 5 {
            pattern = "灵活型（追涨抄底均有）"
        } else if openBuy > closeBuy {
            pattern = "偏好开盘买入（积极进攻）"
        } else if closeSell > openSell {
            pattern = "偏好尾盘卖出（稳健收割）"
        } else {
            pattern = "时机选择较均衡"
        }

        let confidence: String
        if validTrades.count >= 10 { confidence = "高（10笔+交易）" }
        else if validTrades.count >= 5 { confidence = "中（5-9笔交易）" }
        else { confidence = "低（数据不足）" }

        return TimingResult(pattern: pattern, chasingScore: chasingScore, bottomFishingScore: bottomScore, confidence: confidence)
    }

    // MARK: - 三审：风险预警

    private func generateWarnings(_ trades: [Trade], validTrades: [Trade], stats: StatsResult, holding: HoldingResult) -> [String] {
        var warnings: [String] = []

        if stats.cancelRate > 0.3 {
            warnings.append("🔴 撤单率过高（\(Int(stats.cancelRate * 100))%），下单前建议再确认")
        } else if stats.cancelRate > 0.2 {
            warnings.append("🟡 撤单率偏高（\(Int(stats.cancelRate * 100))%），有提升空间")
        }

        if let maxRepeat = stats.stockCounts.values.max(), maxRepeat >= 5 {
            if let topStock = stats.stockCounts.max(by: { $0.value < $1.value })?.key {
                warnings.append("🔴 \(topStock)交易过于频繁（\(maxRepeat)笔），短线风险高度集中")
            }
        } else if let maxRepeat = stats.stockCounts.values.max(), maxRepeat >= 3 {
            if let topStock = stats.stockCounts.max(by: { $0.value < $1.value })?.key {
                warnings.append("🟡 \(topStock)反复操作（\(maxRepeat)笔），注意短线波动风险")
            }
        }

        if stats.completionRate < 0.7 {
            warnings.append("🟡 成交率偏低（\(Int(stats.completionRate * 100))%），注意价格波动导致的废单")
        }

        return warnings
    }

    private func computeRiskLevel(validTrades: [Trade], stats: StatsResult, warnings: [String]) -> String {
        let redWarnings = warnings.filter { $0.contains("🔴") || $0.contains("⚠️") }

        if redWarnings.count >= 2 { return "高" }
        else if redWarnings.count >= 1 { return "中高" }
        else if stats.cancelRate > 0.25 { return "中高" }
        else if stats.cancelRate > 0.15 { return "中" }
        else { return "中低" }
    }

    // MARK: - 洞察生成

    private func generateInsights(_ trades: [Trade], validTrades: [Trade], stats: StatsResult, holding: HoldingResult, style: String, pnl: PnLResult, sector: SectorResult, timing: TimingResult) -> [String] {
        var insights: [String] = []

        insights.append("操作风格：\(style)，平均持股 \(String(format: "%.1f", holding.avgHoldingDays)) 天")

        if pnl.netPnl > 0 {
            insights.append("💰 累计估算盈利：\(pnl.estimatedProfit)（\(Int(pnl.winRate * 100))%胜率，盈亏比\(pnl.profitLossRatio)）")
        } else if pnl.netPnl < 0 {
            insights.append("📉 累计估算亏损：\(pnl.estimatedLoss)")
        }

        if !sector.sectorPreference.isEmpty && sector.sectorPreference != "数据不足" {
            insights.append("📈 偏好板块：\(sector.sectorPreference)（\(sector.marketCapPreference)）")
        }

        if !timing.pattern.isEmpty && timing.pattern != "时机选择较均衡" {
            insights.append("⏰ 时机特征：\(timing.pattern)")
        }

        for warning in warnings where warning.contains("🔴") || warning.contains("⚠️") {
            insights.append(warning)
        }

        if trades.count >= 3 {
            let dates = Set(trades.compactMap { t -> String? in
                guard t.datetime.count >= 8 else { return nil }
                return String(t.datetime.prefix(8))
            })
            if dates.count >= 2 {
                let sortedDates = dates.sorted()
                if let first = parseDate(sortedDates.first!), let last = parseDate(sortedDates.last!) {
                    let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1
                    let freq = Double(trades.count) / Double(max(days, 1))
                    if freq >= 1 {
                        insights.append("📊 交易频率：日均 \(String(format: "%.1f", freq)) 笔，\(dates.count) 个交易日共 \(trades.count) 笔操作")
                    }
                }
            }
        }

        return insights
    }

    // MARK: - 个性化建议

    private func generateAdvice(_ trades: [Trade], validTrades: [Trade], stats: StatsResult, holding: HoldingResult, pnl: PnLResult, sector: SectorResult, personality: PersonalityTags, behaviorInsights: [String]) -> [PersonalizedAdvice] {
        var advice: [PersonalizedAdvice] = []

        let primaryTags = personality.primary

        // 止损线建议
        if primaryTags.contains(where: { ["快进快出型", "超短线（≤1天）", "短线"].contains($0) }) {
            if let worst = pnl.detail.min(by: { $0.pnlPct < $1.pnlPct }), worst.pnlPct < -3 {
                advice.append(PersonalizedAdvice(
                    title: "止损线",
                    content: "\(worst.stock)建议设止损在\(String(format: "%.2f", worst.sellPrice * 0.98))元（-2%）",
                    why: "短线操作胜率50%左右，不设止损的亏损可能远超收益",
                    priority: "高"
                ))
            }
        }

        // 仓位上限
        if let maxCount = stats.stockCounts.values.max(), let topStock = stats.stockCounts.max(by: { $0.value < $1.value })?.key {
            let concentration = Double(maxCount) / Double(max(trades.count, 1))
            if concentration > 0.2 {
                advice.append(PersonalizedAdvice(
                    title: "仓位上限",
                    content: "单只股票仓位不超过总资金的20%，\(topStock)已超过\(Int(concentration * 100))%",
                    why: "凯利公式：短线单笔仓位>20%时，长期期望收益为负",
                    priority: "高"
                ))
            }
        }

        // 撤单率
        if stats.cancelRate > 0.2 {
            advice.append(PersonalizedAdvice(
                title: "下单确认",
                content: "撤单率\(Int(stats.cancelRate * 100))%偏高，下单前建议再确认价格",
                why: "高频撤单可能错过机会，也会影响券商评级",
                priority: "中"
            ))
        }

        // 月度复盘
        advice.append(PersonalizedAdvice(
            title: "月度复盘",
            content: "每月1号回顾上月交易记录，分析盈亏原因",
            why: "定期复盘是专业投资者的标准行为习惯",
            priority: "低"
        ))

        return advice
    }

    // MARK: - 能力雷达

    private func generateRadar(_ trades: [Trade], validTrades: [Trade], stats: StatsResult, holding: HoldingResult, pnl: PnLResult) -> [String: CapabilityDimension] {
        var radar: [String: CapabilityDimension] = [:]

        // 选股能力
        let stockScore: Int
        if pnl.winRate >= 0.7 { stockScore = 5 }
        else if pnl.winRate >= 0.5 { stockScore = 4 }
        else if pnl.winRate >= 0.4 { stockScore = 3 }
        else if pnl.winRate >= 0.3 { stockScore = 2 }
        else { stockScore = 1 }
        radar["选股能力"] = CapabilityDimension(score: stockScore, raw: "\(Int(pnl.winRate * 100))%", reason: pnl.winRate >= 0.5 ? "高于平均" : "低于平均")

        // 择时能力 (简化)
        let timingScore: Int
        if pnl.winRate >= 0.6 { timingScore = 5 }
        else if pnl.winRate >= 0.5 { timingScore = 4 }
        else if pnl.winRate >= 0.4 { timingScore = 3 }
        else if pnl.winRate >= 0.3 { timingScore = 2 }
        else { timingScore = 1 }
        radar["择时能力"] = CapabilityDimension(score: timingScore, raw: "\(Int(pnl.winRate * 100))%", reason: "买入3日内盈利\(Int(pnl.winRate * 100))%")

        // 风控能力
        let riskScore: Int
        let maxConcentration = stats.stockCounts.values.isEmpty ? 0 : Double(stats.stockCounts.values.max() ?? 0) / Double(max(trades.count, 1))
        let riskScoreRaw = (1 - stats.cancelRate + (1 - maxConcentration)) / 2
        if riskScoreRaw >= 0.8 { riskScore = 5 }
        else if riskScoreRaw >= 0.6 { riskScore = 4 }
        else if riskScoreRaw >= 0.5 { riskScore = 3 }
        else if riskScoreRaw >= 0.4 { riskScore = 2 }
        else { riskScore = 1 }
        radar["风控能力"] = CapabilityDimension(score: riskScore, raw: "\(Int(riskScoreRaw * 100))%", reason: maxConcentration > 0.4 ? "仓位偏高" : "仓位控制良好")

        // 执行力
        let execRate = 1 - stats.cancelRate
        let execScore: Int
        if execRate >= 0.9 { execScore = 5 }
        else if execRate >= 0.8 { execScore = 4 }
        else if execRate >= 0.7 { execScore = 3 }
        else if execRate >= 0.6 { execScore = 2 }
        else { execScore = 1 }
        radar["执行力"] = CapabilityDimension(score: execScore, raw: "\(Int(execRate * 100))%", reason: "成交率\(Int(stats.completionRate * 100))%")

        // 盈亏比
        let pnlRatio = pnl.lossValue > 0 ? pnl.profitValue / pnl.lossValue : (pnl.profitValue > 0 ? 999 : 0)
        let pnlScore: Int
        if pnlRatio >= 2 { pnlScore = 5 }
        else if pnlRatio >= 1.5 { pnlScore = 4 }
        else if pnlRatio >= 1 { pnlScore = 3 }
        else if pnlRatio >= 0.5 { pnlScore = 2 }
        else { pnlScore = 1 }
        radar["盈亏比"] = CapabilityDimension(score: pnlScore, raw: "\(String(format: "%.1f", pnlRatio)):1", reason: "盈亏比\(String(format: "%.1f", pnlRatio)):1")

        return radar
    }

    // MARK: - 性格标签

    private func generatePersonalityTags(_ trades: [Trade], validTrades: [Trade], holding: HoldingResult, stats: StatsResult, pnl: PnLResult, timing: TimingResult) -> PersonalityTags {
        var primary: [String] = []
        var secondary: [String] = []

        let avgDays = holding.avgHoldingDays

        if avgDays <= 1 { primary.append("超短线（≤1天）") }
        else if avgDays <= 2 { primary.append("快进快出型") }
        else if avgDays <= 5 { primary.append("短线") }
        else if avgDays <= 30 { primary.append("中线") }
        else { primary.append("长线持有者") }

        // 题材猎手判断
        let smallCapCount = stats.stockCounts.filter { name, _ in
            if let info = StockMapper.findByName(name) {
                return ["小盘", "中小盘", "中小成长", "中等科技"].contains(info.cap)
            }
            return false
        }.count
        if smallCapCount > stats.stockCounts.count / 3 {
            secondary.append("题材猎手")
        }

        // 撤单标签
        if stats.cancelRate > 0.25 {
            primary.append("止损犹豫者")
        }

        // 果断派
        if stats.completionRate >= 0.85 && stats.cancelRate < 0.15 {
            secondary.append("果断派")
        }

        // 集中火力
        if let maxCount = stats.stockCounts.values.max(), let topStock = stats.stockCounts.max(by: { $0.value < $1.value })?.key {
            if maxCount >= 3 && Double(maxCount) / Double(max(trades.count, 1)) > 0.4 {
                secondary.append("集中火力型(\(topStock))")
            }
        }

        let summary = primary.joined(separator: " / ") + (secondary.isEmpty ? "" : "（辅助：\(secondary.joined(separator: " / "))）")

        return PersonalityTags(primary: primary, secondary: secondary, summary: summary)
    }
}

// MARK: - Supporting Types

struct TradeData: Codable {
    var version: String = "2.0"
    var createdAt: String?
    var lastUpdated: String?
    var profileVersion: Int?
    var trades: [Trade] = []
    var holdings: [Holding] = []
    var holdingsInitialized: Bool?
    var holdingsSource: String?
    var holdingsNote: String?
    var holdingsLastUpdated: String?
    var profileSummary: UserProfile?

    static func empty() -> TradeData {
        TradeData()
    }
}

struct Holding: Codable, Identifiable {
    var id: String
    var name: String
    var code: String
    var exchange: String
    var quantity: Int
    var source: String
    var addedAt: String

    init(id: String = UUID().uuidString, name: String, code: String, exchange: String = "", quantity: Int, source: String = "用户手动输入", addedAt: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.name = name
        self.code = code
        self.exchange = exchange.isEmpty ? StockMapper.exchangeForCode(code) : exchange
        self.quantity = quantity
        self.source = source
        self.addedAt = addedAt
    }
}

struct InferredHolding {
    var name: String
    var code: String
    var exchange: String
    var quantity: Int
    var source: String
    var note: String
}

struct HoldingsResult {
    var holdings: [Holding]
    var initialized: Bool
    var note: String
    var lastUpdated: String?
}

struct HoldingsInitResult {
    var success: Bool
    var holdings: [Holding]
    var warnings: [String]
    var error: String?
    var message: String?
    var savedAt: String?
}
