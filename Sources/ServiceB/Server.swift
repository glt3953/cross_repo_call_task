import Foundation

// ============================================================
// Server - ServiceB 的 HTTP 服务器（修复版）
// ============================================================
//
// 修复清单:
//  FIX #11: 正确读取完整请求体（基于 Content-Length）
//  FIX #12: 标准化错误响应格式
//  FIX #13: 添加健康检查端点
// ============================================================

class Server {
    private let inventoryManager: InventoryManager
    private let port: Int
    private var serverSocket: Int32 = -1
    private var isRunning = false

    init(port: Int = 8081, inventoryManager: InventoryManager = InventoryManager()) {
        self.port = port
        self.inventoryManager = inventoryManager
    }

    /// 启动服务器
    func start() throws {
        print("[Server] ServiceB 库存服务启动于 http://localhost:\(port)")

        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw ServerError.socketCreationFailed
        }

        var reuse = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else {
            throw ServerError.bindFailed
        }

        guard listen(serverSocket, 10) >= 0 else {
            throw ServerError.listenFailed
        }

        isRunning = true

        Task.detached { [weak self] in
            await self?.acceptLoop()
        }
    }

    /// 接受连接循环
    private func acceptLoop() async {
        while isRunning {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { continue }

            DispatchQueue.global().async { [weak self] in
                self?.handleConnection(clientSocket)
            }
        }
    }

    /// FIX #11: 基于 Content-Length 正确读取完整请求体
    private func handleConnection(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        // 第一步：读取请求头
        var headerBuffer = [UInt8](repeating: 0, count: 8192)
        let headerBytes = read(clientSocket, &headerBuffer, headerBuffer.count)
        guard headerBytes > 0 else { return }

        let requestString = String(bytes: headerBuffer[0..<headerBytes], encoding: .utf8) ?? ""
        let lines = requestString.components(separatedBy: "\r\n")

        guard let firstLine = lines.first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }

        let method = parts[0]
        let path = parts[1]

        // 解析 Content-Length
        var contentLength = 0
        for line in lines {
            if line.lowercased().hasPrefix("content-length:") {
                if let lengthStr = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces),
                   let length = Int(lengthStr) {
                    contentLength = length
                }
                break
            }
        }

        // FIX #11: 基于 Content-Length 读取请求体
        var body: String? = nil
        if contentLength > 0 {
            // 检查 headerBuffer 中是否已包含部分 body
            if let separatorRange = requestString.range(of: "\r\n\r\n") {
                let afterHeader = String(requestString[separatorRange.upperBound...])
                var bodyData = Data(afterHeader.utf8)

                // 如果 body 不完整，继续读取
                while bodyData.count < contentLength {
                    var extraBuffer = [UInt8](repeating: 0, count: contentLength - bodyData.count)
                    let extraBytes = read(clientSocket, &extraBuffer, extraBuffer.count)
                    guard extraBytes > 0 else { break }
                    bodyData.append(Data(extraBuffer[0..<extraBytes]))
                }

                body = String(data: bodyData, encoding: .utf8)
            }
        }

        let response = route(method: method, path: path, body: body)
        sendResponse(clientSocket, response)
    }

    /// 路由分发
    private func route(method: String, path: String, body: String?) -> (Int, String) {
        // FIX #13: 健康检查端点
        if method == "GET" && path == "/health" {
            return (200, "{\"status\":\"ok\",\"service\":\"inventory\"}")
        }

        // GET /api/v1/inventory/{productId}
        if method == "GET" && path.hasPrefix("/api/v1/inventory/") {
            let productId = String(path.dropFirst("/api/v1/inventory/".count))
            guard !productId.isEmpty else {
                return (400, jsonError("缺少 productId"))
            }

            let result = inventoryManager.query(productId: productId)

            let responseDict: [String: Any] = [
                "productId": result.productId,
                "availableQuantity": result.availableQuantity,
                "reserved": false,
            ]
            return (200, jsonString(from: responseDict))
        }

        // POST /api/v1/inventory/reserve
        if method == "POST" && path == "/api/v1/inventory/reserve" {
            guard let body = body,
                  let bodyData = body.data(using: .utf8),
                  let requestDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  let productId = requestDict["productId"] as? String,
                  let quantity = requestDict["quantity"] as? Int,
                  let orderId = requestDict["orderId"] as? String
            else {
                return (400, jsonError("无效的请求体"))
            }

            let result = inventoryManager.reserve(productId: productId, quantity: quantity, orderId: orderId)

            let responseDict: [String: Any] = [
                "success": result.success,
                "message": result.message,
                "remainingQuantity": result.remainingQuantity,
            ]

            let statusCode = result.success ? 200 : 409
            return (statusCode, jsonString(from: responseDict))
        }

        return (404, jsonError("路由不存在: \(method) \(path)"))
    }

    // MARK: - 工具方法

    private func jsonString(from dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // FIX #12: 标准化错误响应格式
    private func jsonError(_ message: String) -> String {
        let dict: [String: Any] = [
            "error": true,
            "message": message,
        ]
        return jsonString(from: dict)
    }

    /// 发送 HTTP 响应
    private func sendResponse(_ socket: Int32, _ response: (statusCode: Int, body: String)) {
        let statusText: String
        switch response.statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 409: statusText = "Conflict"
        default: statusText = "Internal Server Error"
        }

        let httpResponse = """
        HTTP/1.1 \(response.statusCode) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(response.body.utf8.count)\r
        Connection: close\r
        \r
        \(response.body)
        """

        guard let data = httpResponse.data(using: .utf8) else { return }
        _ = data.withUnsafeBytes { ptr in
            write(socket, ptr.baseAddress, data.count)
        }
    }

    /// 停止服务器
    func stop() {
        isRunning = false
        close(serverSocket)
        print("[Server] 服务器已停止")
    }
}

enum ServerError: LocalizedError {
    case socketCreationFailed
    case bindFailed
    case listenFailed

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed: return "Socket 创建失败"
        case .bindFailed: return "端口绑定失败"
        case .listenFailed: return "监听失败"
        }
    }
}
