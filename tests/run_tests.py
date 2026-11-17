#!/usr/bin/env python3
"""统一测试入口：发现 tests/ 下全部用例，输出 report.txt。"""

import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

TESTS = Path(__file__).resolve().parent
REPORT = TESTS / "report.txt"


def main():
    verbosity = 2 if "-v" in sys.argv else 1
    loader = unittest.TestLoader()
    suite = loader.discover(str(TESTS), pattern="test_*.py", top_level_dir=str(TESTS))

    stream = open(REPORT, "w", encoding="utf-8")
    stream.write("源码测试报告\n")
    stream.write("时间: " + datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ") + "\n")
    stream.write("说明: 本报告只代表源码层测试，不代表可编译或真机可用。\n")
    stream.write("=" * 60 + "\n")

    runner = unittest.TextTestRunner(stream=stream, verbosity=verbosity)
    result = runner.run(suite)

    total = result.testsRun
    failed = len(result.failures) + len(result.errors) + len(result.unexpectedSuccesses)
    skipped = len(result.skipped)
    expected_failures = len(result.expectedFailures)
    passed = total - failed - skipped - expected_failures
    summary = (f"\n结果: 总计 {total}, 通过 {passed}, 失败 {failed}, "
               f"跳过 {skipped}, 预期失败 {expected_failures}\n")
    stream.write(summary)
    stream.close()

    print(summary.strip())
    print("报告: " + str(REPORT))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
