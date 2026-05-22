import Foundation

// ============================================================
// main.swift - 程序入口（修复版）
// 启动两个服务并执行跨仓库调用测试
// ============================================================

@main
struct CrossRepoCallApp {
    static func main() async throws {
        print("=" + String(repeating: "=", count: 59))
        print("  跨仓库调用 Coding Agent 示例 - CrossRepoCall (修复版)")
        print("  ServiceA (OrderService)  <-->  ServiceB (InventoryService)")
        print("=" + String(repeating: "=", count: 59))
        print()

        // 1. 启动 ServiceB 库存服务
        let inventoryManager = InventoryManager()
        let server = Server(port: 8081, inventoryManager: inventoryManager)
        try server.start()

        // 等待服务器就绪
        try await Task.sleep(nanoseconds: 500_000_000)

        // 2. 启动 ServiceA 订单服务
        let apiClient = APIClient()
        let orderHandler = OrderHandler(apiClient: apiClient)

        // 3. 执行单笔订单测试
        let singleTestCases: [(String, OrderRequest, OrderResponse.OrderStatus)] = [
            (
                "正常下单",
                OrderRequest(orderId: "ORD-001", productId: "P001", quantity: 5, customerId: "C001"),
                .confirmed
            ),
            (
                "库存不足",
                OrderRequest(orderId: "ORD-002", productId: "P004", quantity: 100, customerId: "C002"),
                .rejected
            ),
            (
                "幂等性测试",
                OrderRequest(orderId: "ORD-001", productId: "P001", quantity: 5, customerId: "C001"),
                .confirmed
            ),
            (
                "产品不存在",
                OrderRequest(orderId: "ORD-003", productId: "P999", quantity: 1, customerId: "C004"),
                .rejected
            ),
        ]

        print("\n=== 单笔订单测试 ===")
        var singlePassed = 0
        var singleFailed = 0

        for (name, order, expectedStatus) in singleTestCases {
            print("\n--- 测试: \(name) ---")
            let response = await orderHandler.processOrder(order)

            let status = response.status == expectedStatus ? "PASS" : "FAIL"
            print("  状态: \(status) | 预期: \(expectedStatus.rawValue) | 实际: \(response.status.rawValue)")
            print("  信息: \(response.message)")

            if response.status == expectedStatus {
                singlePassed += 1
            } else {
                singleFailed += 1
            }
        }

        // 4. 重置库存，执行并发测试
        inventoryManager.reset()

        print("\n\n=== 并发批量订单测试 ===")
        let batchOrders: [OrderRequest] = [
            OrderRequest(orderId: "BATCH-001", productId: "P001", quantity: 30, customerId: "C001"),
            OrderRequest(orderId: "BATCH-002", productId: "P001", quantity: 30, customerId: "C002"),
            OrderRequest(orderId: "BATCH-003", productId: "P001", quantity: 30, customerId: "C003"),
            OrderRequest(orderId: "BATCH-004", productId: "P001", quantity: 30, customerId: "C004"),
        ]

        let batchResponses = await orderHandler.processOrdersBatch(batchOrders)

        for response in batchResponses {
            print("  订单 \(response.orderId): \(response.status.rawValue) - \(response.message)")
        }

        // 验证最终库存
        let finalInventory = inventoryManager.query(productId: "P001")
        print("\n  P001 最终库存: \(finalInventory.availableQuantity)")
        print("  预期: 100 - 4*30 = -20(不应该出现，证明并发控制正确)")

        // 5. 输出结果
        print("\n" + String(repeating: "=", count: 60))
        print("  单笔测试: \(singlePassed) 通过 / \(singleFailed) 失败  (总计 \(singlePassed + singleFailed))")
        print("  并发测试: 已执行 \(batchOrders.count) 个并发请求")
        print("  最终库存 P001: \(finalInventory.availableQuantity)")
        print(String(repeating: "=", count: 60))

        try await Task.sleep(nanoseconds: 300_000_000)
        server.stop()
    }
}
