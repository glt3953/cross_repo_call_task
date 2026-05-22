#!/bin/bash
# solve_macOS.sh - macOS 环境修复脚本
set -e

echo "=========================================="
echo "  跨仓库调用 - 应用修复方案 (macOS)"
echo "=========================================="

cd "$(dirname "$0")"

cp Solutions/ServiceA/APIClient_fixed.swift Sources/ServiceA/APIClient.swift
cp Solutions/ServiceA/OrderHandler_fixed.swift Sources/ServiceA/OrderHandler.swift
cp Solutions/ServiceB/InventoryManager_fixed.swift Sources/ServiceB/InventoryManager.swift
cp Solutions/ServiceB/Server_fixed.swift Sources/ServiceB/Server.swift
cp Solutions/App.swift Sources/App.swift

swift build
echo "✅ 修复完成！"
