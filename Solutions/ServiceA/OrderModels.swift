import Foundation

// ============================================================
// ServiceA: 订单服务 (OrderService) - 修复版
// 负责接收订单请求，通过 API 调用 ServiceB 查询/预留库存
// ============================================================

// MARK: - 数据模型

/// 订单请求
struct OrderRequest: Codable {
    let orderId: String
    let productId: String
    let quantity: Int
    let customerId: String
}

/// 订单响应
struct OrderResponse: Codable {
    let orderId: String
    let status: OrderStatus
    let message: String

    enum OrderStatus: String, Codable {
        case confirmed
        case rejected
        case pending
    }
}

/// 库存查询响应（来自 ServiceB）
struct InventoryResponse: Codable {
    let productId: String
    let availableQuantity: Int
    let reserved: Bool
}

/// 库存预留请求（发给 ServiceB）
struct ReserveRequest: Codable {
    let productId: String
    let quantity: Int
    let orderId: String
}

/// 库存预留响应（来自 ServiceB）
struct ReserveResponse: Codable {
    let success: Bool
    let message: String
    let remainingQuantity: Int
}
