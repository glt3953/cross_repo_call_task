import Foundation

// ============================================================
// InventoryManager - 库存管理核心逻辑（修复版）
// ============================================================
//
// 修复清单:
//  FIX #9: 使用 NSLock 保护并发读写
//  FIX #10: 预留操作原子化（检查和扣减在同一锁内）
// ============================================================

class InventoryManager {
    // FIX #9: 使用锁保护并发访问
    private let lock = NSLock()

    private var inventory: [String: Int] = [
        "P001": 100,
        "P002": 50,
        "P003": 200,
        "P004": 30,
        "P005": 75,
    ]

    private var reservedOrders: Set<String> = []

    /// 查询库存（读操作加锁）
    func query(productId: String) -> InventoryQueryResponse {
        lock.lock()
        defer { lock.unlock() }
        let qty = inventory[productId] ?? 0
        return InventoryQueryResponse(productId: productId, availableQuantity: qty)
    }

    /// 预留库存（FIX #10: 检查和扣减原子化）
    func reserve(productId: String, quantity: Int, orderId: String) -> InventoryReserveResponse {
        lock.lock()
        defer { lock.unlock() }

        guard let current = inventory[productId] else {
            return InventoryReserveResponse(
                success: false,
                message: "产品不存在",
                remainingQuantity: 0
            )
        }

        // 检查和扣减在同一个锁内，确保是原子操作
        guard current >= quantity else {
            return InventoryReserveResponse(
                success: false,
                message: "库存不足: 需要 \(quantity), 可用 \(current)",
                remainingQuantity: current
            )
        }

        // 检查是否已预留（幂等性）
        if reservedOrders.contains(orderId) {
            return InventoryReserveResponse(
                success: true,
                message: "已预留（幂等）",
                remainingQuantity: current
            )
        }

        // 扣减库存
        let newQuantity = current - quantity
        inventory[productId] = newQuantity
        reservedOrders.insert(orderId)

        return InventoryReserveResponse(
            success: true,
            message: "库存预留成功",
            remainingQuantity: newQuantity
        )
    }

    /// 获取所有库存（用于测试验证）
    func getAllInventory() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return inventory
    }

    /// 重置库存（用于测试）
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        inventory = [
            "P001": 100,
            "P002": 50,
            "P003": 200,
            "P004": 30,
            "P005": 75,
        ]
        reservedOrders = []
    }
}
