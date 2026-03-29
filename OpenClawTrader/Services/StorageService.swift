import Foundation

//
//  StorageService.swift
//  OpenClawTrader
//
//  功能：本地存储服务，管理UserDefaults和Keychain
//

// ============================================
// MARK: - Storage Service
// ============================================

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let apiBaseURL = "api_base_url"
        static let apiKey = "api_key"
        static let isConnected = "is_connected"
        static let selectedWorkspaceId = "selected_workspace_id"
        static let notificationsEnabled = "notifications_enabled"
        static let priceAlertEnabled = "price_alert_enabled"
        static let tradeNotificationsEnabled = "trade_notifications_enabled"
        static let watchlist = "watchlist"
        static let currentUser = "current_user"
    }

    private init() {}

    // MARK: - API Configuration

    var apiBaseURL: String {
        get { userDefaults.string(forKey: Keys.apiBaseURL) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.apiBaseURL) }
    }

    var apiKey: String {
        get { userDefaults.string(forKey: Keys.apiKey) ?? "" }
        set { userDefaults.set(newValue, forKey: Keys.apiKey) }
    }

    var isConnected: Bool {
        get { userDefaults.bool(forKey: Keys.isConnected) }
        set { userDefaults.set(newValue, forKey: Keys.isConnected) }
    }

    // MARK: - Workspace

    var selectedWorkspaceId: String? {
        get { userDefaults.string(forKey: Keys.selectedWorkspaceId) }
        set { userDefaults.set(newValue, forKey: Keys.selectedWorkspaceId) }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.notificationsEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    var priceAlertEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.priceAlertEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.priceAlertEnabled) }
    }

    var tradeNotificationsEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.tradeNotificationsEnabled) }
        set { userDefaults.set(newValue, forKey: Keys.tradeNotificationsEnabled) }
    }

    // MARK: - Watchlist

    /// 自选股列表
    var watchlist: [String] {
        get { userDefaults.stringArray(forKey: Keys.watchlist) ?? [] }
        set { userDefaults.set(newValue, forKey: Keys.watchlist) }
    }

    /// 添加股票到自选列表
    /// - Parameter symbol: 股票代码
    func addToWatchlist(_ symbol: String) {
        var list = watchlist
        if !list.contains(symbol) {
            list.append(symbol)
            watchlist = list
        }
    }

    /// 从自选列表移除股票
    /// - Parameter symbol: 股票代码
    func removeFromWatchlist(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
    }

    // MARK: - Connection

    /// 保存 OpenClaw 连接信息
    /// - Parameters:
    ///   - baseURL: API 基础地址
    ///   - apiKey: API 密钥
    func saveConnection(baseURL: String, apiKey: String) {
        self.apiBaseURL = baseURL
        self.apiKey = apiKey
        self.isConnected = true
    }

    /// 断开 OpenClaw 连接
    func disconnect() {
        apiBaseURL = ""
        apiKey = ""
        isConnected = false
        selectedWorkspaceId = nil
    }

    /// 注销账号 - 清除所有数据
    func deleteAccount() {
        // 清除所有 UserDefaults 数据
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
    }

    // MARK: - User

    /// 保存用户信息
    /// - Parameter user: 用户对象
    func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: Keys.currentUser)
        }
    }

    /// 获取保存的用户信息
    /// - Returns: 用户对象，如果不存在返回 nil
    func getUser() -> User? {
        guard let data = userDefaults.data(forKey: Keys.currentUser),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }

    /// 清除用户信息
    func clearUser() {
        userDefaults.removeObject(forKey: Keys.currentUser)
    }
}
