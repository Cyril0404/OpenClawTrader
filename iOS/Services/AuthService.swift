import Foundation

//
//  AuthService.swift
//  OpenClawTrader
//
//  功能：用户认证服务，支持登录/注册/登出
//

// ============================================
// MARK: - API Models
// ============================================

/// 通用API响应
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String?
    let data: T?
}

/// 发送验证码响应
struct SendCodeResponse: Codable {
    // success: { "code": 0, "message": "验证码已发送" }
}

/// 注册+登录响应
struct VerifyResponse: Codable {
    let userId: String
    let token: String
    let expiresIn: Int
}

/// 登录响应
struct LoginResponse: Codable {
    let userId: String
    let token: String
    let expiresIn: Int
}

/// 用户资料响应
struct ProfileResponse: Codable {
    let userId: String
    let phone: String
    let nickname: String?
    let createdAt: Int64
    let status: String
}

// ============================================
// MARK: - Auth Service
// ============================================

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    /// 是否已登录（计算属性）
    var isLoggedIn: Bool {
        currentUser != nil && !StorageService.shared.authToken.isEmpty
    }

    /// 妙股AI后端服务器地址
    private let baseURL = "http://150.158.119.114:3001"

    private init() {
        // 启动时加载保存的用户
        loadCurrentUser()
    }

    // MARK: - Public API

    /// 发送注册验证码
    /// - Parameter phone: 手机号
    /// - Returns: 是否成功
    func sendRegisterCode(phone: String) async -> Bool {
        guard isValidPhone(phone) else {
            error = "手机号格式不正确"
            return false
        }

        isLoading = true
        error = nil

        do {
            let url = URL(string: "\(baseURL)/api/v1/auth/register")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let body = ["phone": phone]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效响应"])
            }

            let apiResponse = try JSONDecoder().decode(APIResponse<SendCodeResponse>.self, from: data)

            if apiResponse.code == 0 {
                isLoading = false
                return true
            } else {
                error = apiResponse.message ?? "发送验证码失败"
                isLoading = false
                return false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 注册+登录（验证码确认）
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 验证码
    ///   - password: 密码
    /// - Returns: 是否成功
    func verifyAndRegister(phone: String, code: String, password: String) async -> Bool {
        guard isValidPhone(phone) else {
            error = "手机号格式不正确"
            return false
        }

        guard code.count == 6 else {
            error = "验证码格式不正确"
            return false
        }

        guard isStrongPassword(password) else {
            error = "密码至少8位，需含大小写字母和数字"
            return false
        }

        isLoading = true
        error = nil

        do {
            let url = URL(string: "\(baseURL)/api/v1/auth/verify")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let body = ["phone": phone, "code": code, "password": password] as [String: Any]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效响应"])
            }

            let apiResponse = try JSONDecoder().decode(APIResponse<VerifyResponse>.self, from: data)

            if apiResponse.code == 0, let responseData = apiResponse.data {
                // 保存token
                StorageService.shared.authToken = responseData.token

                // 创建用户
                let user = User(id: responseData.userId, phone: phone)
                saveUser(user)
                currentUser = user

                isLoading = false
                return true
            } else {
                error = apiResponse.message ?? "注册失败"
                isLoading = false
                return false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 登录
    /// - Parameters:
    ///   - phone: 手机号
    ///   - password: 密码
    /// - Returns: 是否登录成功
    func login(phone: String, password: String) async -> Bool {
        guard isValidPhone(phone) else {
            error = "手机号格式不正确"
            return false
        }

        guard !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "密码不能为空"
            return false
        }

        isLoading = true
        error = nil

        do {
            let url = URL(string: "\(baseURL)/api/v1/auth/login")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let body = ["phone": phone, "password": password] as [String: Any]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效响应"])
            }

            let apiResponse = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: data)

            if apiResponse.code == 0, let responseData = apiResponse.data {
                // 保存token
                StorageService.shared.authToken = responseData.token

                // 创建用户
                let user = User(id: responseData.userId, phone: phone)
                saveUser(user)
                currentUser = user

                isLoading = false
                return true
            } else {
                error = apiResponse.message ?? "登录失败"
                isLoading = false
                return false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 登出
    func logout() async {
        let token = StorageService.shared.authToken
        guard !token.isEmpty else {
            clearUser()
            currentUser = nil
            return
        }

        isLoading = true

        do {
            let url = URL(string: "\(baseURL)/api/v1/auth/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            // 忽略登出API错误，仍然清除本地数据
        }

        // 清除本地数据
        StorageService.shared.authToken = ""
        clearUser()
        currentUser = nil
        isLoading = false
    }

    /// 刷新用户资料（从服务器获取）
    func refreshProfile() async -> Bool {
        let token = StorageService.shared.authToken
        guard !token.isEmpty else {
            return false
        }

        do {
            let url = URL(string: "\(baseURL)/api/v1/auth/profile")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return false
            }

            let apiResponse = try JSONDecoder().decode(APIResponse<ProfileResponse>.self, from: data)

            if apiResponse.code == 0, let profileData = apiResponse.data {
                let user = User(
                    id: profileData.userId,
                    phone: profileData.phone,
                    nickname: profileData.nickname
                )
                saveUser(user)
                currentUser = user
                return true
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func loadCurrentUser() {
        if let user = StorageService.shared.getUser() {
            currentUser = user
        }
    }

    private func saveUser(_ user: User) {
        StorageService.shared.saveUser(user)
    }

    private func clearUser() {
        StorageService.shared.clearUser()
    }

    // MARK: - Validation

    private func isValidPhone(_ phone: String) -> Bool {
        let pattern = "^1[3-9]\\d{9}$"
        return phone.range(of: pattern, options: .regularExpression) != nil
    }

    private func isStrongPassword(_ password: String) -> Bool {
        // 至少8位，含大小写和数字
        return password.count >= 8 &&
               password.contains(where: { $0.isUppercase }) &&
               password.contains(where: { $0.isLowercase }) &&
               password.contains(where: { $0.isNumber })
    }

    // MARK: - 兼容旧接口（username实为phone）

    /// 兼容旧接口的登录（username实为phone）
    @MainActor
    func login(username: String, password: String) async -> Bool {
        return await login(phone: username, password: password)
    }

    /// 兼容旧接口的注册（直接登录，因为旧流程无短信验证）
    /// 注意：旧UI的注册入口已废弃，新的注册流程需要短信验证
    @MainActor
    func register(username: String, password: String, email: String?) async -> Bool {
        // 旧注册流程没有短信验证，直接尝试登录（用户可能已存在）
        // 如果登录失败，说明用户不存在，这里返回失败
        let success = await login(phone: username, password: password)
        if !success && error == "手机号或密码错误" {
            // 用户不存在，但无法注册（需要短信验证）
            self.error = "请使用手机号+验证码方式注册"
            return false
        }
        return success
    }
}
