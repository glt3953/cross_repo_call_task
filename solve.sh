#!/bin/bash
# solve.sh - 修复跨仓库调用的所有 bug
set -e

echo "=========================================="
echo "  跨仓库调用 - 应用修复方案"
echo "=========================================="

cd "$(dirname "$0")"

echo "[STEP 1] 备份原始源码..."
cp Sources/ServiceA/APIClient.swift Sources/ServiceA/APIClient.swift.bak
cp Sources/ServiceA/OrderHandler.swift Sources/ServiceA/OrderHandler.swift.bak
cp Sources/ServiceB/InventoryManager.swift Sources/ServiceB/InventoryManager.swift.bak
cp Sources/ServiceB/Server.swift Sources/ServiceB/Server.swift.bak

echo "[STEP 2] 应用修复代码..."
cp Solutions/ServiceA/APIClient_fixed.swift Sources/ServiceA/APIClient.swift
cp Solutions/ServiceA/OrderHandler_fixed.swift Sources/ServiceA/OrderHandler.swift
cp Solutions/ServiceB/InventoryManager_fixed.swift Sources/ServiceB/InventoryManager.swift
cp Solutions/ServiceB/Server_fixed.swift Sources/ServiceB/Server.swift
cp Solutions/App.swift Sources/App.swift

echo "[STEP 3] 编译验证..."
swift build

echo ""
echo "✅ 修复完成！运行 ./test.sh 验证结果。"
echo "  原始文件已备份为 .bak 后缀。"
