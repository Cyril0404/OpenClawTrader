import XCTest
@testable import OpenClawTrader

final class TradeProfileServiceTests: XCTestCase {

    var service: TradeProfileService!

    override func setUp() {
        super.setUp()
        service = TradeProfileService.shared
        // 清空数据保证测试独立
        service.clearAllTrades()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 添加交易记录测试

    func testAddSingleTrade() {
        let trade = createSampleTrade(
            stockName: "永泰能源",
            stockCode: "600157",
            datetime: "20260330 09:32:11",
            direction: "买入",
            status: "已成",
            entrustPrice: 1.98,
            dealPrice: 1.98,
            entrustQty: 27100,
            dealQty: 27100
        )

        let added = service.addTrades([trade])
        XCTAssertEqual(added, 1)

        let trades = service.getAllTrades()
        XCTAssertEqual(trades.count, 1)
        XCTAssertEqual(trades[0].stockName, "永泰能源")
    }

    func testAddDuplicateTradeSkipped() {
        let trade = createSampleTrade(
            stockName: "永泰能源",
            stockCode: "600157",
            datetime: "20260330 09:32:11",
            direction: "买入",
            status: "已成",
            entrustPrice: 1.98,
            dealPrice: 1.98
        )

        _ = service.addTrades([trade])
        let added2 = service.addTrades([trade])

        // 重复记录不应被添加
        XCTAssertEqual(added2, 0)
        XCTAssertEqual(service.getAllTrades().count, 1)
    }

    func testCancelStatusReplacement() {
        // 先添加已撤单
        let cancelledTrade = createSampleTrade(
            stockName: "永泰能源",
            stockCode: "600157",
            datetime: "20260330 09:32:11",
            direction: "买入",
            status: "已撤",
            entrustPrice: 1.98
        )
        _ = service.addTrades([cancelledTrade])

        // 后添加已成
        let completedTrade = createSampleTrade(
            stockName: "永泰能源",
            stockCode: "600157",
            datetime: "20260330 09:32:11",
            direction: "买入",
            status: "已成",
            entrustPrice: 1.98,
            dealPrice: 1.98,
            dealQty: 27100
        )
        _ = service.addTrades([completedTrade])

        let trades = service.getAllTrades()
        // 已成替换已撤，所以只有1条
        XCTAssertEqual(trades.count, 1)
        XCTAssertEqual(trades[0].status, "已成")
    }

    // MARK: - 画像生成测试

    func testGenerateProfileWithNoTrades() {
        let profile = service.generateProfile()
        XCTAssertEqual(profile.confidence, "低")
        XCTAssertTrue(profile.insights.contains { $0.contains("暂无") || $0.contains("上传") })
    }

    func testGenerateProfileWithSampleData() {
        // 添加多笔交易
        let trades = createSampleTrades()
        _ = service.addTrades(trades)

        let profile = service.generateProfile()

        XCTAssertEqual(profile.totalTrades, trades.count)
        XCTAssertGreaterThan(profile.doneTrades, 0)
        XCTAssertFalse(profile.style.isEmpty)
        XCTAssertFalse(profile.oneLiner.isEmpty)
    }

    func testStyleAnalysis() {
        // 短线交易
        let shortTermTrades = createShortTermTrades()
        _ = service.addTrades(shortTermTrades)

        let profile = service.generateProfile()

        XCTAssertTrue(profile.style.contains("短线") || profile.style.contains("超短线"))
    }

    func testWinRateCalculation() {
        let trades = createSampleTrades()
        _ = service.addTrades(trades)

        let profile = service.generateProfile()

        XCTAssertGreaterThanOrEqual(profile.winRate, 0)
        XCTAssertLessThanOrEqual(profile.winRate, 1)
    }

    // MARK: - 持仓推算测试

    func testInferHoldings() {
        let trades = [
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260330 09:32:11", direction: "买入", status: "已成", dealPrice: 1.98, dealQty: 10000),
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260331 10:00:00", direction: "卖出", status: "已成", dealPrice: 2.00, dealQty: 5000),
        ]
        _ = service.addTrades(trades)

        let inferred = service.inferHoldings()

        XCTAssertEqual(inferred.count, 1)
        XCTAssertEqual(inferred[0].name, "永泰能源")
        XCTAssertEqual(inferred[0].quantity, 5000) // 10000买入 - 5000卖出 = 5000
    }

    func testInferHoldingsWithNoSell() {
        let trades = [
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260330 09:32:11", direction: "买入", status: "已成", dealPrice: 1.98, dealQty: 10000),
        ]
        _ = service.addTrades(trades)

        let inferred = service.inferHoldings()

        XCTAssertEqual(inferred.count, 1)
        XCTAssertEqual(inferred[0].quantity, 10000) // 只有买入，全部推定持有
    }

    // MARK: - 辅助方法

    private func createSampleTrade(
        stockName: String,
        stockCode: String,
        datetime: String,
        direction: String,
        status: String,
        entrustPrice: Double? = nil,
        dealPrice: Double? = nil,
        entrustQty: Double? = nil,
        dealQty: Double? = nil
    ) -> Trade {
        Trade(
            stockName: stockName,
            stockCode: stockCode,
            exchange: stockCode.hasPrefix("6") ? "沪A" : "深A",
            datetime: datetime,
            direction: direction,
            status: status,
            entrustPrice: entrustPrice,
            dealPrice: dealPrice,
            entrustQty: entrustQty,
            dealQty: dealQty
        )
    }

    private func createSampleTrades() -> [Trade] {
        [
            // 永泰能源 - 买入
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260330 09:32:11", direction: "买入", status: "已成", entrustPrice: 1.98, dealPrice: 1.98, entrustQty: 27100, dealQty: 27100),
            // 兆易创新 - 买入
            createSampleTrade(stockName: "兆易创新", stockCode: "603986", datetime: "20260331 10:15:00", direction: "买入", status: "已成", entrustPrice: 278.0, dealPrice: 278.0, entrustQty: 100, dealQty: 100),
            // 兆易创新 - 卖出
            createSampleTrade(stockName: "兆易创新", stockCode: "603986", datetime: "20260401 14:30:00", direction: "卖出", status: "已成", entrustPrice: 280.0, dealPrice: 280.0, entrustQty: 100, dealQty: 100),
            // 皖能电力 - 买入
            createSampleTrade(stockName: "皖能电力", stockCode: "000543", datetime: "20260402 09:45:00", direction: "买入", status: "已成", entrustPrice: 5.50, dealPrice: 5.50, entrustQty: 6000, dealQty: 6000),
            // 协鑫能科 - 已撤
            createSampleTrade(stockName: "协鑫能科", stockCode: "002015", datetime: "20260403 11:20:00", direction: "买入", status: "已撤", entrustPrice: 12.50),
        ]
    }

    private func createShortTermTrades() -> [Trade] {
        [
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260401 09:30:00", direction: "买入", status: "已成", dealPrice: 2.00, dealQty: 10000),
            createSampleTrade(stockName: "永泰能源", stockCode: "600157", datetime: "20260402 09:30:00", direction: "卖出", status: "已成", dealPrice: 2.05, dealQty: 10000),
            createSampleTrade(stockName: "兆易创新", stockCode: "603986", datetime: "20260403 09:30:00", direction: "买入", status: "已成", dealPrice: 280.0, dealQty: 100),
            createSampleTrade(stockName: "兆易创新", stockCode: "603986", datetime: "20260404 09:30:00", direction: "卖出", status: "已成", dealPrice: 285.0, dealQty: 100),
        ]
    }
}
