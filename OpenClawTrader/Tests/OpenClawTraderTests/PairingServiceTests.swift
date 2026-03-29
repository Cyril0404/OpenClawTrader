import XCTest
@testable import OpenClawTrader

@MainActor
final class PairingServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PairingService.shared.deletePairingKey()
    }

    override func tearDown() {
        PairingService.shared.deletePairingKey()
        super.tearDown()
    }

    // MARK: - Pairing State Tests

    func testIsPairedReturnsFalseWhenNoKey() {
        XCTAssertFalse(PairingService.shared.isPaired)
    }

    func testIsPairedReturnsTrueWhenKeyExists() {
        PairingService.shared.savePairingKey("test-token-123")
        XCTAssertTrue(PairingService.shared.isPaired)
    }

    // MARK: - Keychain Operations

    func testSaveAndGetPairingKey() {
        let token = "my-secret-token"
        PairingService.shared.savePairingKey(token)

        XCTAssertEqual(PairingService.shared.getPairingKey(), token)
    }

    func testDeletePairingKey() {
        PairingService.shared.savePairingKey("test-token")
        PairingService.shared.deletePairingKey()

        XCTAssertNil(PairingService.shared.getPairingKey())
        XCTAssertFalse(PairingService.shared.isPaired)
    }

    // MARK: - Gateway Token

    func testGatewayTokenReturnsPairingKey() {
        let token = "gateway-token-xyz"
        PairingService.shared.savePairingKey(token)

        XCTAssertEqual(PairingService.shared.gatewayToken, token)
    }

    // MARK: - Unbind

    func testUnbindClearsKeyAndDisconnects() {
        PairingService.shared.savePairingKey("test-token")
        StorageService.shared.saveConnection(baseURL: "https://api.test.com", apiKey: "key")
        StorageService.shared.isConnected = true

        PairingService.shared.unbind()

        XCTAssertFalse(PairingService.shared.isPaired)
        XCTAssertTrue(StorageService.shared.apiBaseURL.isEmpty)
        XCTAssertFalse(StorageService.shared.isConnected)
    }

    // MARK: - Relay API

    func testRelayAPIDefaultValue() {
        // relayAPI 应该有一个默认值
        XCTAssertFalse(PairingService.shared.relayAPI.isEmpty)
    }
}
