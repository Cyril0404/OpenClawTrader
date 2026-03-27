import Foundation

// ============================================
// MARK: - API Client
// ============================================

actor APIClient {
    static let shared = APIClient()

    private var baseURL: String = "https://api.openclaw.example.com/v1"
    private var apiKey: String?

    private init() {}

    func configure(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    // MARK: - Generic Request

    func request<T: Decodable>(_ endpoint: String, method: HTTPMethod = .get, body: Encodable? = nil) async throws -> T {
        guard let apiKey = apiKey else {
            throw APIError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    enum APIError: Error, LocalizedError {
        case notConfigured
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "API 未配置"
            case .invalidURL: return "无效的 URL"
            case .invalidResponse: return "无效的响应"
            case .httpError(let statusCode): return "HTTP 错误: \(statusCode)"
            case .decodingError(let error): return "解码错误: \(error.localizedDescription)"
            }
        }
    }
}
