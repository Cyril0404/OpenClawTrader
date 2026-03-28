import Foundation
import Security

//
//  PairingService.swift
//  OpenClawTrader
//
//  功能：移动端配对服务，管理与桌面端 Gateway 的配对
//

// ============================================
// MARK: - Pairing Service
// ============================================

@MainActor
class PairingService: ObservableObject {
    static let shared = PairingService()

    @Published var pairingStatus: PairingStatus = .idle
    @Published var currentCode: String?
    @Published var qrCodeData: String?
    @Published var pairedDevices: [PairedDevice] = []
    @Published var errorMessage: String?

    private let gatewayBaseURL = "http://localhost:18789"

    enum PairingStatus: Equatable {
        case idle
        case generating
        case ready
        case scanning
        case verifying
        case paired
        case error(String)

        static func == (lhs: PairingStatus, rhs: PairingStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.generating, .generating): return true
            case (.ready, .ready): return true
            case (.scanning, .scanning): return true
            case (.verifying, .verifying): return true
            case (.paired, .paired): return true
            case (.error(let lhsMsg), .error(let rhsMsg)): return lhsMsg == rhsMsg
            default: return false
            }
        }
    }

    struct PairedDevice: Identifiable, Codable {
        let id: String
        let name: String
        let gatewayId: String
        let connectedAt: Date
        var isConnected: Bool
    }

    struct PairingCodeResponse: Codable {
        let code: String
        let expiresAt: String
        let gatewayId: String
    }

    struct PairingVerifyRequest: Encodable {
        let code: String
        let deviceId: String
        let deviceName: String
        let deviceType: String
    }

    struct PairingVerifyResponse: Codable {
        let success: Bool
        let gatewayToken: String?
        let error: String?
    }

    private init() {
        loadPairedDevices()
    }

    // MARK: - Generate Pairing Code

    /// 生成配对码
    func generatePairingCode() async {
        pairingStatus = .generating
        errorMessage = nil

        do {
            guard let url = URL(string: "\(gatewayBaseURL)/api/pairing/code") else {
                throw PairingError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = getGatewayToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PairingError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let codeResponse = try JSONDecoder().decode(PairingCodeResponse.self, from: data)
                currentCode = codeResponse.code
                qrCodeData = "openclaw://pair/\(codeResponse.code)"
                pairingStatus = .ready
            } else {
                throw PairingError.serverError(httpResponse.statusCode)
            }
        } catch {
            errorMessage = error.localizedDescription
            pairingStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Verify Pairing Code

    /// 验证配对码
    func verifyPairingCode(_ code: String) async -> Bool {
        pairingStatus = .verifying
        errorMessage = nil

        let deviceId = getDeviceId()
        let deviceName = getDeviceName()

        do {
            guard let url = URL(string: "\(gatewayBaseURL)/api/pairing/verify") else {
                throw PairingError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let verifyRequest = PairingVerifyRequest(
                code: code,
                deviceId: deviceId,
                deviceName: deviceName,
                deviceType: "ios"
            )

            request.httpBody = try JSONEncoder().encode(verifyRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PairingError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let verifyResponse = try JSONDecoder().decode(PairingVerifyResponse.self, from: data)

                if verifyResponse.success, let token = verifyResponse.gatewayToken {
                    saveGatewayToken(token)
                    pairingStatus = .paired
                    return true
                } else {
                    errorMessage = verifyResponse.error ?? "验证失败"
                    pairingStatus = .error(verifyResponse.error ?? "验证失败")
                    return false
                }
            } else {
                throw PairingError.serverError(httpResponse.statusCode)
            }
        } catch {
            errorMessage = error.localizedDescription
            pairingStatus = .error(error.localizedDescription)
            return false
        }
    }

    // MARK: - QR Code Parsing

    /// 解析二维码内容
    func parseQRCode(_ content: String) -> String? {
        // 支持格式: openclaw://pair/A3B7K9
        if content.hasPrefix("openclaw://pair/") {
            let code = String(content.dropFirst("openclaw://pair/".count))
            return code.isEmpty ? nil : code
        }

        // 直接是配对码
        if content.count == 6 && content.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return content.uppercased()
        }

        return nil
    }

    // MARK: - Device Info

    private func getDeviceId() -> String {
        if let stored = UserDefaults.standard.string(forKey: "pairedDeviceId") {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "pairedDeviceId")
        return newId
    }

    private func getDeviceName() -> String {
        UserDefaults.standard.string(forKey: "pairedDeviceName") ?? "我的 iPhone"
    }

    // MARK: - Token Storage (Keychain)

    func saveGatewayToken(_ token: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openclaw_gateway_token",
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getGatewayToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openclaw_gateway_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteGatewayToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "openclaw_gateway_token"
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Paired Devices

    private func loadPairedDevices() {
        if let data = UserDefaults.standard.data(forKey: "pairedDevices"),
           let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) {
            pairedDevices = devices
        }
    }

    private func savePairedDevices() {
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: "pairedDevices")
        }
    }

    func addPairedDevice(_ device: PairedDevice) {
        pairedDevices.append(device)
        savePairedDevices()
    }

    func removePairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.id == device.id }
        savePairedDevices()
    }

    func disconnect() {
        deleteGatewayToken()
        pairingStatus = .idle
        currentCode = nil
        qrCodeData = nil
    }

    // MARK: - Reset

    func reset() {
        pairingStatus = .idle
        currentCode = nil
        qrCodeData = nil
        errorMessage = nil
    }

    // MARK: - Errors

    enum PairingError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case serverError(Int)
        case tokenExpired
        case pairingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的 URL"
            case .invalidResponse:
                return "无效的响应"
            case .serverError(let code):
                return "服务器错误: \(code)"
            case .tokenExpired:
                return "配对已过期，请重新配对"
            case .pairingFailed(let message):
                return message
            }
        }
    }
}