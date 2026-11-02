"""The parallel runner must preserve discovery errors, assertion failures and nonzero exits."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "test-tooling.py"


class ToolingRunnerTests(unittest.TestCase):
    def run_fixture(self, source):
        with tempfile.TemporaryDirectory(prefix="Can I Wear runner ") as directory:
            if source is not None:
                (Path(directory) / "test_fixture.py").write_text(source)
            return subprocess.run([sys.executable, str(RUNNER), directory],
                                  text=True, capture_output=True, timeout=30)

    def test_all_tests_execute_and_explicitly_safe_cases_run_concurrently(self):
        result = self.run_fixture("import unittest, threading\nbarrier = threading.Barrier(2)\n"
                                  "class Probe(unittest.TestCase):\n parallel_safe = True\n"
                                  " def test_one(self): barrier.wait(timeout=5)\n"
                                  " def test_two(self): barrier.wait(timeout=5)\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("2 tests, 0 failures", result.stdout)

    def test_failure_does_not_hide_other_tests_or_report_success(self):
        result = self.run_fixture("import unittest\nclass Probe(unittest.TestCase):\n"
                                  " def test_one(self): self.fail('fixture failure')\n"
                                  " def test_two(self): self.assertEqual(2, 2)\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture failure", result.stderr)
        self.assertIn("PASS: test_fixture.Probe.test_two", result.stdout)
        self.assertIn("2 tests, 1 failures", result.stdout)

    def test_discovery_error_and_empty_suite_are_failures(self):
        for source in (None, "this is not valid Python !"):
            with self.subTest(source=source):
                result = self.run_fixture(source)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("FAIL: tooling test discovery", result.stderr)

    def test_skipped_checks_are_not_reported_as_passed(self):
        result = self.run_fixture("import unittest\nclass Probe(unittest.TestCase):\n"
                                  " @unittest.skip('fixture skip')\n def test_one(self): pass\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture skip", result.stderr)


if __name__ == "__main__":
    unittest.main()
