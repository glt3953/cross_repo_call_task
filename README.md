# CrossRepoCall - 跨仓库调用 Coding Agent 示例

## 项目简介

这是一个用于评估 Coding Agent 能力的示例项目，模拟微服务架构下两个独立代码仓库间的跨服务 API 调用场景。

## 业务场景

**订单服务 (ServiceA)** 需要调用 **库存服务 (ServiceB)** 来完成以下操作：

```
┌──────────────────────────────────────────────────────┐
│                     Client Request                    │
│   POST /order { productId, quantity, customerId }     │
└─────────────────────┬────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────┐
│  ServiceA (OrderService)           port: N/A          │
│                                                        │
│  1. 接收订单请求                                       │
│  2. 调用 ServiceB 查询库存 ───────────────┐            │
│  3. 调用 ServiceB 预留库存 ───────────────┤            │
│  4. 返回订单确认/拒绝                      │            │
└───────────────────────────────────────────┼──────────┘
                                            │
                      HTTP REST API         │
                                            ▼
┌──────────────────────────────────────────────────────┐
│  ServiceB (InventoryService)      port: 8081          │
│                                                        │
│  GET   /api/v1/inventory/{productId}  → 查询库存      │
│  POST  /api/v1/inventory/reserve       → 预留库存      │
│  GET   /health                         → 健康检查      │
└──────────────────────────────────────────────────────┘
```

### API 接口定义

#### ServiceB API

**查询库存**
```
GET /api/v1/inventory/{productId}

Response 200:
{
    "productId": "P001",
    "availableQuantity": 100,
    "reserved": false
}
```

**预留库存**
```
POST /api/v1/inventory/reserve

Request:
{
    "productId": "P001",
    "quantity": 5,
    "orderId": "ORD-001"
}

Response 200 (成功):
{
    "success": true,
    "message": "库存预留成功",
    "remainingQuantity": 95
}

Response 409 (库存不足):
{
    "success": false,
    "message": "库存不足: 需要 5, 可用 3",
    "remainingQuantity": 3
}
```

## Bug 修复清单

| # | 文件 | 问题 | 修复方案 |
|---|------|------|----------|
| 1 | APIClient.swift | baseURL 端口错误 (8080 → 8081) | 修正端口号 |
| 2 | APIClient.swift | 未设置请求超时 | 配置 timeoutIntervalForRequest |
| 3 | APIClient.swift | 未检查 HTTP 状态码 | 添加状态码检查逻辑 |
| 4 | APIClient.swift | 无重试机制 | 添加指数退避重试 |
| 5 | OrderHandler.swift | 竞态条件（查询-预留间隙） | 依赖服务端原子预留 |
| 6 | OrderHandler.swift | processedOrders 非线程安全 | 改用 actor |
| 7 | InventoryManager.swift | 并发下检查和修改非原子 | NSLock 保护 |
| 8 | InventoryManager.swift | 无并发保护 | NSLock 保护所有操作 |
| 9 | Server.swift | 请求体读取不完整 | 基于 Content-Length 读取 |
| 10 | Server.swift | 错误响应格式不规范 | 标准化 JSON 错误格式 |

## 快速开始

```bash
# 查看任务说明
cat instruction.md

# 直接编译（会因 bug 导致部分测试失败）
swift build && swift run

# 应用修复
./solve.sh

# 验证修复
./test.sh
```

## 技术栈

- **语言**: Swift 5.9+
- **构建工具**: Swift Package Manager
- **并发模型**: Swift Concurrency (async/await, Actor, Task)
- **网络**: Foundation URLSession
- **HTTP 服务**: 基于 BSD Socket 的简易实现
- **测试**: Shell + Python3
