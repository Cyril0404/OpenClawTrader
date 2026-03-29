import XCTest
@testable import OpenClawTrader

final class StorageServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 清除连接数据
        StorageService.shared.disconnect()
        StorageService.shared.clearUser()
    }

    override func tearDown() {
        StorageService.shared.disconnect()
        StorageService.shared.clearUser()
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testSaveAndLoadConnection() {
        StorageService.shared.saveConnection(baseURL: "https://api.test.com", apiKey: "test-api-key")

        XCTAssertEqual(StorageService.shared.apiBaseURL, "https://api.test.com")
        XCTAssertEqual(StorageService.shared.apiKey, "test-api-key")
    }

    func testApiBaseURLReturnsCorrectValue() {
        StorageService.shared.saveConnection(baseURL: "https://openclaw.example.com", apiKey: "key123")

        XCTAssertEqual(StorageService.shared.apiBaseURL, "https://openclaw.example.com")
    }

    func testApiKeyReturnsCorrectValue() {
        StorageService.shared.saveConnection(baseURL: "https://api.test.com", apiKey: "secret-key-456")

        XCTAssertEqual(StorageService.shared.apiKey, "secret-key-456")
    }

    func testDisconnect() {
        StorageService.shared.saveConnection(baseURL: "https://api.test.com", apiKey: "key")
        StorageService.shared.isConnected = true

        StorageService.shared.disconnect()

        XCTAssertEqual(StorageService.shared.apiBaseURL, "")
        XCTAssertEqual(StorageService.shared.apiKey, "")
        XCTAssertFalse(StorageService.shared.isConnected)
    }

    // MARK: - User Tests

    func testSaveAndGetUser() {
        let user = User(id: "user-123", username: "testuser", email: "test@example.com")

        StorageService.shared.saveUser(user)
        let loadedUser = StorageService.shared.getUser()

        XCTAssertNotNil(loadedUser)
        XCTAssertEqual(loadedUser?.id, "user-123")
        XCTAssertEqual(loadedUser?.username, "testuser")
        XCTAssertEqual(loadedUser?.email, "test@example.com")
    }

    func testClearUser() {
        let user = User(id: "user-123", username: "testuser", email: "test@example.com")
        StorageService.shared.saveUser(user)

        StorageService.shared.clearUser()
        let loadedUser = StorageService.shared.getUser()

        XCTAssertNil(loadedUser)
    }

    // MARK: - API Base URL Validation

    func testEmptyBaseURLWhenNotConnected() {
        XCTAssertTrue(StorageService.shared.apiBaseURL.isEmpty)
    }

    func testNonEmptyBaseURLWhenConnected() {
        StorageService.shared.saveConnection(baseURL: "https://api.test.com", apiKey: "key")

        XCTAssertFalse(StorageService.shared.apiBaseURL.isEmpty)
    }
}
