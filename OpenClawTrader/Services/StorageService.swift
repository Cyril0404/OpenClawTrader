import Foundation

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

    var watchlist: [String] {
        get { userDefaults.stringArray(forKey: Keys.watchlist) ?? [] }
        set { userDefaults.set(newValue, forKey: Keys.watchlist) }
    }

    func addToWatchlist(_ symbol: String) {
        var list = watchlist
        if !list.contains(symbol) {
            list.append(symbol)
            watchlist = list
        }
    }

    func removeFromWatchlist(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
    }

    // MARK: - Connection

    func saveConnection(baseURL: String, apiKey: String) {
        self.apiBaseURL = baseURL
        self.apiKey = apiKey
        self.isConnected = true
    }

    func disconnect() {
        apiBaseURL = ""
        apiKey = ""
        isConnected = false
        selectedWorkspaceId = nil
    }
}
