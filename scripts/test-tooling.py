"""Parallelize explicitly isolated orchestration tests; keep other unittest cases serial."""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
import unittest


def test_cases(suite):
    for test in suite:
        if isinstance(test, unittest.TestSuite):
            yield from test_cases(test)
        else:
            yield test


def run(directory):
    loader = unittest.TestLoader()
    tests = list(test_cases(loader.discover(str(directory))))
    if loader.errors or not tests:
        print("FAIL: tooling test discovery\n" + "\n".join(loader.errors), file=sys.stderr)
        return 1

    def execute(test):
        result = unittest.TestResult()
        test.run(result)
        return test.id(), result

    failures = 0
    serial = [test for test in tests if not getattr(test, "parallel_safe", False)]
    parallel = [test for test in tests if getattr(test, "parallel_safe", False)]
    results = [execute(test) for test in serial]
    # Only opt-in cases: each verification invocation has isolated files, env and a new process group.
    with ThreadPoolExecutor(max_workers=4) as pool:
        results.extend(pool.map(execute, parallel))
    for identifier, result in results:
        failed = not result.wasSuccessful() or bool(result.skipped)
        print(f"{'FAIL' if failed else 'PASS'}: {identifier}")
        if failed:
            failures += 1
            for _, error in result.errors + result.failures + result.skipped:
                print(error, file=sys.stderr)
    print(f"Tooling: {len(tests)} tests, {failures} failures (up to 4 isolated orchestration workers)")
    return int(failures != 0)


if __name__ == "__main__":
    if len(sys.argv) > 2:
        sys.exit("Usage: test-tooling.py [TEST_DIRECTORY]")
    sys.exit(run(Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else Path(__file__).resolve().parent / "tests"))
