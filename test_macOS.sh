#!/bin/bash
set -e

echo "=========================================="
echo "  跨仓库调用测试脚本 (macOS)"
echo "=========================================="

cd "$(dirname "$0")"

echo "[STEP 1] 编译项目..."
swift build 2>&1 | tail -5

echo ""
echo "[STEP 2] 运行程序..."
swift run 2>&1

echo ""
echo "[STEP 3] 运行 Python 状态验证..."
python3 test_state.py
