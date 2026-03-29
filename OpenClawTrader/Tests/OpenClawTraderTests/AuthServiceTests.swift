import XCTest
@testable import OpenClawTrader

@MainActor
final class AuthServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 清除保存的用户数据
        StorageService.shared.clearUser()
        AuthService.shared.logout()
    }

    override func tearDown() {
        AuthService.shared.logout()
        StorageService.shared.clearUser()
        super.tearDown()
    }

    func testLoginWithEmptyUsername() async {
        let result = await AuthService.shared.login(username: "", password: "password123")
        XCTAssertFalse(result)
        XCTAssertNotNil(AuthService.shared.error)
    }

    func testLoginWithEmptyPassword() async {
        let result = await AuthService.shared.login(username: "testuser", password: "")
        XCTAssertFalse(result)
        XCTAssertNotNil(AuthService.shared.error)
    }

    func testLoginSuccess() async {
        let result = await AuthService.shared.login(username: "testuser", password: "password123")
        XCTAssertTrue(result)
        XCTAssertTrue(AuthService.shared.isLoggedIn)
        XCTAssertNotNil(AuthService.shared.currentUser)
        XCTAssertEqual(AuthService.shared.currentUser?.username, "testuser")
    }

    func testLoginPreservesUserId() async {
        // 第一次登录
        let result1 = await AuthService.shared.login(username: "user1", password: "password123")
        XCTAssertTrue(result1)
        guard let userId1 = AuthService.shared.currentUser?.id else {
            XCTFail("User ID should not be nil")
            return
        }

        // 登出
        AuthService.shared.logout()

        // 第二次登录同一个用户名
        let result2 = await AuthService.shared.login(username: "user1", password: "password123")
        XCTAssertTrue(result2)
        guard let userId2 = AuthService.shared.currentUser?.id else {
            XCTFail("User ID should not be nil")
            return
        }

        // 用户ID应该保持一致
        XCTAssertEqual(userId1, userId2, "User ID should be preserved across logins")
    }

    func testRegisterWithShortPassword() async {
        let result = await AuthService.shared.register(username: "testuser", password: "12345", email: nil)
        XCTAssertFalse(result)
        XCTAssertEqual(AuthService.shared.error, "密码长度至少6位")
    }

    func testRegisterSuccess() async {
        let result = await AuthService.shared.register(username: "newuser", password: "password123", email: "test@example.com")
        XCTAssertTrue(result)
        XCTAssertTrue(AuthService.shared.isLoggedIn)
        XCTAssertEqual(AuthService.shared.currentUser?.username, "newuser")
        XCTAssertEqual(AuthService.shared.currentUser?.email, "test@example.com")
    }

    func testLogout() async {
        await AuthService.shared.login(username: "testuser", password: "password123")
        XCTAssertTrue(AuthService.shared.isLoggedIn)

        AuthService.shared.logout()
        XCTAssertFalse(AuthService.shared.isLoggedIn)
        XCTAssertNil(AuthService.shared.currentUser)
    }

    func testLoadCurrentUser() async {
        // 先登录保存用户
        await AuthService.shared.login(username: "persistuser", password: "password123")

        // 模拟 App 重启，使用同一个 singleton
        XCTAssertNotNil(AuthService.shared.currentUser, "Current user should be loaded from storage on init")
    }
}
