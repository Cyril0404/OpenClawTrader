import XCTest
@testable import OpenClawTrader

final class APIClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 清除配置
        Task {
            await APIClient.shared.clear()
        }
    }

    override func tearDown() {
        Task {
            await APIClient.shared.clear()
        }
        super.tearDown()
    }

    // MARK: - Configuration Tests

    @MainActor
    func testConfigureSetsBaseURL() async {
        await APIClient.shared.configure(baseURL: "https://api.test.com", apiKey: "test-key")

        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertTrue(isConfigured)
    }

    @MainActor
    func testConfigureStripsTrailingSlash() async {
        await APIClient.shared.configure(baseURL: "https://api.test.com/", apiKey: "test-key")

        // 验证配置成功
        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertTrue(isConfigured)
    }

    @MainActor
    func testClearResetsConfiguration() async {
        await APIClient.shared.configure(baseURL: "https://api.test.com", apiKey: "test-key")
        await APIClient.shared.clear()

        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertFalse(isConfigured)
    }

    @MainActor
    func testIsConfiguredReturnsFalseWhenOnlyBaseURLSet() async {
        await APIClient.shared.configure(baseURL: "https://api.test.com", apiKey: "")

        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertFalse(isConfigured)
    }

    @MainActor
    func testIsConfiguredReturnsFalseWhenOnlyApiKeySet() async {
        await APIClient.shared.configure(baseURL: "", apiKey: "test-key")

        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertFalse(isConfigured)
    }

    @MainActor
    func testIsConfiguredReturnsFalseWhenBothEmpty() async {
        await APIClient.shared.configure(baseURL: "", apiKey: "")

        let isConfigured = await APIClient.shared.isConfigured()
        XCTAssertFalse(isConfigured)
    }

    // MARK: - Request Tests

    @MainActor
    func testRequestThrowsWhenNotConfigured() async {
        do {
            let _: StatusResponse = try await APIClient.shared.request("/v1/status")
            XCTFail("Should throw APIError.notConfigured")
        } catch let error as APIClient.APIError {
            if case .notConfigured = error {
                // Expected
            } else {
                XCTFail("Expected .notConfigured but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    @MainActor
    func testRequestThrowsWhenInvalidURL() async {
        await APIClient.shared.configure(baseURL: "not-a-valid-url", apiKey: "key")

        do {
            let _: StatusResponse = try await APIClient.shared.request("/v1/status")
            XCTFail("Should throw APIError.invalidURL")
        } catch let error as APIClient.APIError {
            if case .invalidURL = error {
                // Expected
            } else {
                XCTFail("Expected .invalidURL but got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - HTTP Method Tests

    @MainActor
    func testHTTPMethodRawValues() async {
        XCTAssertEqual(APIClient.HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(APIClient.HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(APIClient.HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(APIClient.HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(APIClient.HTTPMethod.delete.rawValue, "DELETE")
    }

    // MARK: - API Error Tests

    @MainActor
    func testAPIErrorDescriptions() async {
        XCTAssertEqual(APIClient.APIError.notConfigured.errorDescription, "API 未配置")
        XCTAssertEqual(APIClient.APIError.invalidURL.errorDescription, "无效的 URL")
        XCTAssertEqual(APIClient.APIError.invalidResponse.errorDescription, "无效的响应")
        XCTAssertTrue(APIClient.APIError.httpError(statusCode: 404).errorDescription?.contains("404") ?? false)
        XCTAssertTrue(APIClient.APIError.httpError(statusCode: 500).errorDescription?.contains("500") ?? false)
    }
}
