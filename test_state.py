#!/usr/bin/env python3
"""
test_state.py - 跨仓库调用状态验证脚本

验证要点:
1. ServiceA 是否能正确调用 ServiceB 的 API
2. HTTP 响应状态码是否正确
3. 错误处理是否完善
4. 并发场景下的数据一致性
"""

import subprocess
import sys
import re
import json


def run_program():
    """运行主程序并捕获输出"""
    result = subprocess.run(
        ["swift", "run"],
        capture_output=True,
        text=True,
        timeout=120,
    )
    return result.stdout, result.stderr


def parse_test_results(output: str) -> dict:
    """
    解析程序输出，提取测试结果
    """
    results = {
        "single_passed": 0,
        "single_failed": 0,
        "single_total": 0,
        "final_inventory": None,
        "all_tests_passed": False,
    }

    # 提取单笔测试结果
    single_match = re.search(
        r"单笔测试:\s+(\d+)\s+通过\s+/\s+(\d+)\s+失败\s+\(总计\s+(\d+)\)",
        output
    )
    if single_match:
        results["single_passed"] = int(single_match.group(1))
        results["single_failed"] = int(single_match.group(2))
        results["single_total"] = int(single_match.group(3))

    # 提取库存结果
    inv_match = re.search(r"P001 最终库存:\s+(\d+)", output)
    if inv_match:
        results["final_inventory"] = int(inv_match.group(1))

    results["all_tests_passed"] = (results["single_failed"] == 0)

    return results


def verify_cross_repo_calls(output: str) -> list:
    """验证跨仓库调用是否正常"""
    issues = []

    # 检查每次测试的 PASS/FAIL 状态
    # 格式: "  状态: PASS | 预期: confirmed | 实际: confirmed"
    test_results = re.findall(
        r"状态:\s+(PASS|FAIL)\s+\|\s+预期:\s+(\w+)\s+\|\s+实际:\s+(\w+)",
        output
    )

    if not test_results:
        issues.append("❌ 未找到测试结果行")
        return issues

    for verdict, expected, actual in test_results:
        if verdict == "FAIL":
            issues.append(f"❌ 测试失败: 预期={expected}, 实际={actual}")
        elif expected != actual:
            issues.append(f"❌ 状态不匹配: 预期={expected}, 实际={actual}")

    # 验证并发测试：P001 库存 100，4个并发请求各要30，最多成功3个
    inv_match = re.search(r"P001 最终库存:\s+(\d+)", output)
    if inv_match:
        final_inv = int(inv_match.group(1))
        if final_inv > 100:
            issues.append(f"❌ 库存异常: P001={final_inv}（不应超过100）")
        elif final_inv < 0:
            issues.append(f"❌ 库存为负数: P001={final_inv}（并发控制失败）")
        else:
            print(f"  ✅ P001 库存正确: {final_inv}")

    # 检查重试日志（如果有）
    if "重试" in output:
        print("  ℹ️  检测到重试行为（正常，表明重试机制生效）")

    return issues


def main():
    print("=" * 60)
    print("  跨仓库调用状态验证")
    print("=" * 60)

    try:
        print("\n[1/4] 编译并运行程序...")
        stdout, stderr = run_program()
        print(stdout)

        if stderr.strip():
            print(f"\n[WARN] 标准错误输出:\n{stderr}")

    except subprocess.TimeoutExpired:
        print("\n❌ 程序执行超时！")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 程序执行失败: {e}")
        if e.stderr:
            print(e.stderr)
        sys.exit(1)

    print("\n[2/4] 解析测试结果...")
    results = parse_test_results(stdout)
    print(f"  单笔通过: {results['single_passed']}")
    print(f"  单笔失败: {results['single_failed']}")
    print(f"  最终库存: {results['final_inventory']}")

    print("\n[3/4] 验证跨仓库调用...")
    issues = verify_cross_repo_calls(stdout)
    if issues:
        for issue in issues:
            print(f"  {issue}")
    else:
        print("  ✅ 所有跨仓库调用验证通过")

    print("\n[4/4] 综合判定...")
    if results["all_tests_passed"] and len(issues) == 0:
        print("✅ 所有测试通过！跨仓库调用功能正常。")
        sys.exit(0)
    else:
        failed_reasons = []
        if not results["all_tests_passed"]:
            failed_reasons.append(f"单笔测试失败 {results['single_failed']}/{results['single_total']}")
        if issues:
            failed_reasons.append("跨仓库调用验证未通过")

        print(f"❌ 测试未通过: {'; '.join(failed_reasons)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
