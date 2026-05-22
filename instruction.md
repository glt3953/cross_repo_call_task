# 任务：跨仓库调用 Bug 修复

## 背景

你正在开发一个微服务架构下的订单系统。系统包含两个独立服务：

- **ServiceA (OrderService / 订单服务)**：接收订单请求，调用 ServiceB 查询和预留库存
- **ServiceB (InventoryService / 库存服务)**：管理产品库存，提供查询和预留 API

ServiceA 通过 HTTP 协议调用 ServiceB 的 REST API 完成库存操作。

## 任务说明

当前代码存在多个 bug，导致跨服务调用失败或数据不一致。请阅读 `Sources/` 目录下的所有源码文件，找出并修复所有问题。

### 已知 Bug 类型

| 类别 | 描述 |
|------|------|
| 网络层 | URL 配置错误、缺乏超时设置、重试机制缺失 |
| HTTP 层 | 响应状态码未检查、请求体读取不完整 |
| 数据层 | JSON 解析异常未处理、Model 属性不匹配 |
| 并发层 | 竞态条件、非线程安全数据结构、非原子操作 |

### 修复要求

1. APIClient 必须正确连接到 ServiceB（修正 URL）
2. APIClient 必须有请求超时配置和指数退避重试
3. 必须检查所有 HTTP 响应状态码
4. InventoryManager 的库存操作必须是并发安全的
5. OrderHandler 必须正确处理预留失败的情况
6. Server 必须正确处理完整请求体（基于 Content-Length）

## 目录结构

```
.
├── Sources/              # 有 bug 的源代码（需要修复）
│   ├── App.swift          # 程序入口
│   ├── ServiceA/          # 订单服务
│   │   ├── OrderModels.swift   # 数据模型
│   │   ├── APIClient.swift     # HTTP 客户端（Bug #1-4）
│   │   └── OrderHandler.swift  # 订单处理逻辑（Bug #5-6）
│   └── ServiceB/          # 库存服务
│       ├── InventoryModels.swift    # 数据模型
│       ├── InventoryManager.swift   # 库存管理（Bug #7-8）
│       └── Server.swift            # HTTP 服务器（Bug #9-10）
├── Solutions/            # 修复后的参考实现
│   ├── App.swift
│   ├── ServiceA/
│   │   ├── OrderModels.swift
│   │   ├── APIClient_fixed.swift
│   │   └── OrderHandler_fixed.swift
│   └── ServiceB/
│       ├── InventoryModels.swift
│       ├── InventoryManager_fixed.swift
│       └── Server_fixed.swift
├── task.toml             # 任务配置
├── Package.swift         # Swift Package Manager 配置
├── test.sh / test_docker.sh / test_macOS.sh  # 测试脚本
├── solve.sh / solve_docker.sh / solve_macOS.sh # 修复脚本
└── test_state.py         # Python 状态验证
```

## 验证方式

```bash
# 本地测试（使用有 bug 的代码）
./test.sh

# 应用修复方案
./solve.sh

# 重新测试（验证修复结果）
./test.sh
```

## 评分标准

- 全部测试用例通过：满分
- 单笔订单测试全部通过：及格
- 并发测试通过：加分项
