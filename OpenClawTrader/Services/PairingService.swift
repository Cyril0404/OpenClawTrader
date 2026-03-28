import Foundation
import Security

//
//  PairingService.swift
//  OpenClawTrader
//
//  功能：移动端配对服务，对接云端中继服务
//

// ============================================
// MARK: - Pairing Service
// ============================================

@MainActor
class PairingService: ObservableObject {
    static let shared = PairingService()

    @Published var pairingStatus: PairingStatus = .idle
    @Published var errorMessage: String?

    // 云端中继服务器地址
    let relayAPI = "http://150.158.119.114:3001/api"
    private let relayWS = "ws://150.158.119.114:3001"

    private let keychainAccount = "openclaw_pairing_key"

    enum PairingStatus: Equatable {
        case idle
        case scanning
        case verifying
        case connected
        case error(String)

        static func == (lhs: PairingStatus, rhs: PairingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.scanning, .scanning): return true
            case (.verifying, .verifying): return true
            case (.connected, .connected): return true
            case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
            default: return false
            }
        }
    }

    struct PairingInfo {
        let code: String
        let token: String
        let gatewayId: String?
    }

    struct GenerateResponse: Codable {
        let code: String
        let expiresAt: String
        let serverUrl: String
        let token: String
    }

    struct VerifyResponse: Codable {
        let success: Bool
        let gatewayToken: String?
        let gatewayId: String?
        let gatewayApiUrl: String?
        let error: String?
    }

    private init() {}

    // MARK: - Public API

    /// 是否已配对
    var isPaired: Bool {
        getPairingKey() != nil
    }

    /// 获取配对信息
    var gatewayId: String? {
        getPairingKey()
    }

    /// 检查云端服务器连接状态
    func checkServerStatus() async -> Bool {
        guard let url = URL(string: relayAPI) else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            // 任何响应都说明服务器在线
            return httpResponse.statusCode < 500
        } catch {
            return false
        }
    }

    /// 调用云端生成配对码（桌面端用）
    func generatePairingCode() async -> GenerateResponse? {
        guard let url = URL(string: "\(relayAPI)/pair/generate") else {
            errorMessage = "无效的服务器地址"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "生成配对码失败"
                return nil
            }

            let result = try JSONDecoder().decode(GenerateResponse.self, from: data)
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// 解析配对 URL
    /// 格式: openclaw://pair?code=XXX&server=ws://...
    func parsePairingURL(_ urlString: String) -> (code: String, server: String)? {
        guard let components = URLComponents(string: urlString),
              components.scheme == "openclaw",
              components.host == "pair" else {
            return nil
        }

        let queryItems = components.queryItems ?? []
        var paramMap: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                paramMap[item.name] = value
            }
        }

        guard let code = paramMap["code"],
              let server = paramMap["server"] else {
            return nil
        }

        return (code, server)
    }

    /// 验证配对码
    func verifyPairingCode(_ code: String) async -> VerifyResponse? {
        guard let url = URL(string: "\(relayAPI)/pair/verify") else {
            errorMessage = "无效的服务器地址"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ["code": code]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "验证配对码失败"
                return nil
            }

            let result = try JSONDecoder().decode(VerifyResponse.self, from: data)
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// 执行配对流程
    func pairWithURL(_ urlString: String) async -> Bool {
        pairingStatus = .verifying
        errorMessage = nil

        guard let parsed = parsePairingURL(urlString) else {
            errorMessage = "无效的配对码"
            pairingStatus = .error("无效的配对码")
            return false
        }

        guard let result = await verifyPairingCode(parsed.code) else {
            pairingStatus = .error(errorMessage ?? "验证失败")
            return false
        }

        if result.success, let token = result.gatewayToken {
            savePairingKey(token)
            StorageService.shared.saveConnection(baseURL: relayAPI, apiKey: token)
            pairingStatus = .connected
            return true
        } else {
            errorMessage = result.error ?? "配对失败"
            pairingStatus = .error(result.error ?? "配对失败")
            return false
        }
    }

    /// 解绑
    func unbind() {
        deletePairingKey()
        StorageService.shared.disconnect()
        pairingStatus = .idle
    }

    // MARK: - Keychain Storage

    func savePairingKey(_ key: String) {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getPairingKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func deletePairingKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }
}
