import Foundation

// ============================================================
// OrderHandler - 订单处理核心逻辑（修复版）
// ============================================================
//
// 修复清单:
//  FIX #6: 使用 Actor 确保线程安全
//  FIX #7: 预留失败时回退，处理竞态条件
//  FIX #8: 添加并发批量处理支持
// ============================================================

actor OrderHandler {
    private let apiClient: APIClient
    private var processedOrders: Set<String> = []

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    /// 处理新订单
    func processOrder(_ order: OrderRequest) async -> OrderResponse {
        print("[OrderHandler] 收到订单: \(order.orderId)")

        // FIX #6: actor 保证了 processedOrders 的线程安全访问
        if processedOrders.contains(order.orderId) {
            print("[OrderHandler] 订单 \(order.orderId) 已处理，跳过")
            return OrderResponse(
                orderId: order.orderId,
                status: .confirmed,
                message: "订单已处理（幂等）"
            )
        }

        do {
            // 步骤 1: 查询库存
            print("[OrderHandler] 查询库存: productId=\(order.productId)")
            let inventory = try await apiClient.queryInventory(productId: order.productId)

            // 步骤 2: 检查库存是否充足
            guard inventory.availableQuantity >= order.quantity else {
                print("[OrderHandler] 库存不足: 需要 \(order.quantity), 可用 \(inventory.availableQuantity)")
                processedOrders.insert(order.orderId)
                return OrderResponse(
                    orderId: order.orderId,
                    status: .rejected,
                    message: "库存不足"
                )
            }

            // FIX #7: 即使库存查询通过，也通过 ServiceB 的原子预留来最终判断
            // 预留操作在服务端是原子的，避免了竞态条件

            // 步骤 3: 预留库存
            print("[OrderHandler] 预留库存: quantity=\(order.quantity)")
            let reserve = try await apiClient.reserveInventory(
                productId: order.productId,
                quantity: order.quantity,
                orderId: order.orderId
            )

            if reserve.success {
                processedOrders.insert(order.orderId)
                print("[OrderHandler] 订单 \(order.orderId) 已确认")
                return OrderResponse(
                    orderId: order.orderId,
                    status: .confirmed,
                    message: reserve.message
                )
            } else {
                processedOrders.insert(order.orderId)
                return OrderResponse(
                    orderId: order.orderId,
                    status: .rejected,
                    message: reserve.message
                )
            }
        } catch let error as APIError where error.localizedDescription.contains("库存不足") {
            processedOrders.insert(order.orderId)
            return OrderResponse(
                orderId: order.orderId,
                status: .rejected,
                message: "库存不足"
            )
        } catch {
            print("[OrderHandler] 订单 \(order.orderId) 处理失败: \(error)")
            return OrderResponse(
                orderId: order.orderId,
                status: .pending,
                message: "处理异常: \(error.localizedDescription)"
            )
        }
    }

    /// FIX #8: 并发批量处理订单
    func processOrdersBatch(_ orders: [OrderRequest]) async -> [OrderResponse] {
        await withTaskGroup(of: OrderResponse.self) { group in
            for order in orders {
                group.addTask {
                    await self.processOrder(order)
                }
            }

            var responses: [OrderResponse] = []
            for await response in group {
                responses.append(response)
            }
            return responses
        }
    }
}
