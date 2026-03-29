import Foundation

//
//  AuthService.swift
//  OpenClawTrader
//
//  功能：用户认证服务，支持登录/注册/登出
//

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
        currentUser != nil
    }

    private let userKey = "current_user"

    private init() {
        // 启动时加载保存的用户
        loadCurrentUser()
    }

    // MARK: - Public API

    /// 登录
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 是否登录成功
    func login(username: String, password: String) async -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            error = "用户名和密码不能为空"
            return false
        }

        isLoading = true
        error = nil

        // TODO: 调用真实API进行登录验证
        // let response: LoginResponse = try await APIClient.shared.request("/auth/login", method: .post, body: ["username": username, "password": password])

        // 模拟登录成功
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 尝试复用已有用户的 ID，避免每次登录生成新 ID
        let existingUser = StorageService.shared.getUser()
        let user = User(id: existingUser?.id ?? UUID().uuidString, username: username)
        saveUser(user)
        currentUser = user
        isLoading = false
        return true
    }

    /// 注册
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    ///   - email: 邮箱（可选）
    /// - Returns: 是否注册成功
    func register(username: String, password: String, email: String?) async -> Bool {
        guard !username.isEmpty, !password.isEmpty else {
            error = "用户名和密码不能为空"
            return false
        }

        guard password.count >= 6 else {
            error = "密码长度至少6位"
            return false
        }

        isLoading = true
        error = nil

        // TODO: 调用真实API进行注册
        // let response: RegisterResponse = try await APIClient.shared.request("/auth/register", method: .post, body: ["username": username, "password": password, "email": email])

        // 模拟注册成功
        try? await Task.sleep(nanoseconds: 500_000_000)

        let user = User(username: username, email: email)
        saveUser(user)
        currentUser = user
        isLoading = false
        return true
    }

    /// 登出
    func logout() {
        clearUser()
        currentUser = nil
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
}
