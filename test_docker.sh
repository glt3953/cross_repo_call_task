#!/bin/bash
set -e

echo "=========================================="
echo "  跨仓库调用测试脚本 (Docker)"
echo "=========================================="

cd /workspace

# 使用修复后的代码替换源码
echo "[STEP 1] 应用修复代码..."
cp Solutions/ServiceA/APIClient_fixed.swift Sources/ServiceA/APIClient.swift
cp Solutions/ServiceA/OrderHandler_fixed.swift Sources/ServiceA/OrderHandler.swift
cp Solutions/ServiceB/InventoryManager_fixed.swift Sources/ServiceB/InventoryManager.swift
cp Solutions/ServiceB/Server_fixed.swift Sources/ServiceB/Server.swift
cp Solutions/App.swift Sources/App.swift

echo "[STEP 2] 编译项目..."
swift build 2>&1 | tail -5

echo ""
echo "[STEP 3] 运行程序..."
swift run 2>&1

echo ""
echo "[STEP 4] 运行 Python 状态验证..."
python3 test_state.py
