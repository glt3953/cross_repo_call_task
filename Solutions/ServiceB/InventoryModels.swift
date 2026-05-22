import Foundation

// ============================================================
// ServiceB: 库存服务 (InventoryService) - 修复版
// ============================================================

// MARK: - 数据模型

/// 库存查询响应
struct InventoryQueryResponse: Codable {
    let productId: String
    let availableQuantity: Int
}

/// 库存预留请求
struct InventoryReserveRequest: Codable {
    let productId: String
    let quantity: Int
    let orderId: String
}

/// 库存预留响应
struct InventoryReserveResponse: Codable {
    let success: Bool
    let message: String
    let remainingQuantity: Int
}

/// 库存记录
struct InventoryRecord {
    let productId: String
    var quantity: Int
}
