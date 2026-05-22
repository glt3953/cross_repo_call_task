import Foundation

// ============================================================
// APIClient - ServiceA 调用 ServiceB 的 HTTP 客户端（修复版）
// ============================================================
//
// 修复清单:
//  FIX #1: 修正 baseURL 端口为 8081
//  FIX #2: 添加请求超时配置 (30秒)
//  FIX #3: 完整的 HTTP 状态码检查
//  FIX #4: 添加指数退避重试机制
//  FIX #5: 安全的 JSON 解析（try-catch 包裹）
// ============================================================

class APIClient {
    // FIX #1: 修正为正确的端口 8081
    private let baseURL = "http://localhost:8081"

    // FIX #4: 重试配置
    private let maxRetries = 3
    private let baseRetryDelay: UInt64 = 200_000_000 // 200ms

    // FIX #2: 配置超时时间
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0   // 请求超时 30 秒
        config.timeoutIntervalForResource = 60.0  // 资源超时 60 秒
        return URLSession(configuration: config)
    }()

    // MARK: - 查询库存

    func queryInventory(productId: String) async throws -> InventoryResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/inventory/\(productId)") else {
            throw APIError.invalidURL
        }

        return try await fetchWithRetry(url: url, method: "GET", body: nil) { data in
            // FIX #5: try-catch 包裹 JSON 解析
            do {
                return try JSONDecoder().decode(InventoryResponse.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }
    }

    // MARK: - 预留库存

    func reserveInventory(productId: String, quantity: Int, orderId: String) async throws -> ReserveResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/inventory/reserve") else {
            throw APIError.invalidURL
        }

        let body = ReserveRequest(productId: productId, quantity: quantity, orderId: orderId)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        return try await fetchWithRetry(url: url, method: "POST", body: bodyData) { data in
            do {
                return try JSONDecoder().decode(ReserveResponse.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        }
    }

    // MARK: - 通用请求方法（含重试和状态码检查）

    private func fetchWithRetry<T: Decodable>(
        url: URL,
        method: String,
        body: Data?,
        decoder: (Data) throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= maxRetries {
            if attempt > 0 {
                // FIX #4: 指数退避
                let delay = baseRetryDelay * UInt64(1 << (attempt - 1))
                print("[APIClient] 重试 #\(attempt), 等待 \(Double(delay) / 1_000_000_000.0)s")
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                var request = URLRequest(url: url)
                request.httpMethod = method
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                if let body = body {
                    request.httpBody = body
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }

                let (data, urlResponse) = try await session.data(for: request)

                // FIX #3: 完整的 HTTP 状态码检查
                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    throw APIError.networkError(NSError(domain: "APIClient", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无效的 HTTP 响应"]))
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return try decoder(data)

                case 408, 429, 500, 502, 503, 504:
                    // 可重试的服务端错误
                    lastError = APIError.serverError(statusCode: httpResponse.statusCode)
                    attempt += 1
                    continue

                case 409:
                    // 冲突（如库存不足），不可重试
                    throw APIError.inventoryUnavailable

                case 400...499:
                    throw APIError.serverError(statusCode: httpResponse.statusCode)

                default:
                    throw APIError.serverError(statusCode: httpResponse.statusCode)
                }

            } catch let error as APIError {
                // API 层错误直接传播（不重试）
                if case .inventoryUnavailable = error { throw error }
                if case .decodingError = error { throw error }
                throw error
            } catch {
                // 网络层错误可以重试
                lastError = APIError.networkError(error)
                attempt += 1
            }
        }

        throw lastError ?? APIError.networkError(
            NSError(domain: "APIClient", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未知错误"]))
    }
}

// MARK: - 错误类型

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int)
    case inventoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .decodingError(let e): return "数据解析错误: \(e.localizedDescription)"
        case .serverError(let code): return "服务器错误 (状态码: \(code))"
        case .inventoryUnavailable: return "库存不足"
        }
    }
}
