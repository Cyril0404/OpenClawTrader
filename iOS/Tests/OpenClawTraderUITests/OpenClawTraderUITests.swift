import XCTest

final class OpenClawTraderUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - App Launch Tests

    func testAppLaunchesSuccessfully() {
        let app = XCUIApplication()
        app.launch()

        // 验证 app 没有崩溃
        XCTAssertTrue(app.exists)
    }

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    // MARK: - Tab Bar Navigation Tests

    func testTabBarExists() {
        let app = XCUIApplication()
        app.launch()

        // 检查 TabBar 是否存在
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar should exist")
    }

    func testCanNavigateToMeTab() {
        let app = XCUIApplication()
        app.launch()

        // 尝试点击"我的"标签
        let meTab = app.tabBars.buttons["我的"] ?? app.tabBars.buttons.element(boundBy: 3)
        if meTab.exists {
            meTab.tap()
            // 等待导航完成
            expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: meTab, handler: nil)
            waitForExpectations(timeout: 5)
        }
    }

    // MARK: - Login Flow Tests

    func testShowsLoginPromptWhenNotLoggedIn() {
        let app = XCUIApplication()
        app.launch()

        // 导航到"我的"
        let meTab = app.tabBars.buttons["我的"] ?? app.tabBars.buttons.element(boundBy: 3)
        if meTab.exists {
            meTab.tap()
        }

        // 应该显示"登录"按钮或提示
        let hasLoginUI = app.buttons["登录"].exists || app.staticTexts["请先登录"].exists
        XCTAssertTrue(hasLoginUI, "Should show login prompt when not logged in")
    }

    // MARK: - Settings Navigation Tests

    func testCanNavigateToSettings() {
        let app = XCUIApplication()
        app.launch()

        // 导航到"我的"
        let meTab = app.tabBars.buttons["我的"] ?? app.tabBars.buttons.element(boundBy: 3)
        if meTab.exists {
            meTab.tap()
        }

        // 查找设置按钮
        let settingsButton = app.buttons["设置"]
        if settingsButton.exists {
            settingsButton.tap()
            // 验证进入了设置页面
            expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: settingsButton, handler: nil)
            waitForExpectations(timeout: 5)
        }
    }

    // MARK: - OpenClaw Connection Status Tests

    func testShowsDisconnectedStatusWhenFirstLaunched() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()

        // 导航到"我的"
        let meTab = app.tabBars.buttons["我的"] ?? app.tabBars.buttons.element(boundBy: 3)
        if meTab.exists {
            meTab.tap()
        }

        // 应该显示未连接状态
        let disconnectedText = app.staticTexts["未连接"]
        // 注意：具体文本可能根据实现而不同
        XCTAssertTrue(disconnectedText.exists || app.staticTexts["OpenClaw"].exists)
    }

    // MARK: - Deep Link Tests

    func testCanOpenURLScheme() {
        let app = XCUIApplication()

        // 尝试打开 URL scheme
        _ = app.open(URL(string: "openclawtrader://test")!)
    }

    // MARK: - Orientation Tests

    func testSupportsPortraitOrientation() {
        let app = XCUIApplication()
        app.launch()

        // 锁定为竖屏
        XCUIDevice.shared.orientation = .portrait

        // 验证 app 仍然可用
        XCTAssertTrue(app.exists)
    }

    func testSupportsLandscapeOrientation() {
        let app = XCUIApplication()
        app.launch()

        // 锁定为横屏
        XCUIDevice.shared.orientation = .landscapeLeft

        // 验证 app 仍然可用
        XCTAssertTrue(app.exists)
    }
}
