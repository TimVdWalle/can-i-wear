"""Test verification orchestration with fake tools, not simulated app test results."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "verify.sh"
TOOLS = ("git", "shellcheck", "swiftlint", "plutil", "python3", "xcodebuild", "xcrun")
FAKE_TOOL = r"""#!/bin/bash
name="${0##*/}"
# NUL-delimited records retain spaces, quotes and newlines without a Python process per call.
printf '%s\0' "$name" "$#" "$@" >> "$TOOL_CALLS"
if [[ "$name" == "${FAIL_TOOL:-}" ]]; then exit 7; fi
if [[ "$name" == "${INTERRUPT_TOOL:-}" && ( "$name" != xcodebuild || "${!#}" == test ) ]]; then
    target="$PPID"
    if [[ "$INTERRUPT_TARGET" == group ]]; then target=0; fi
    kill -s "${INTERRUPT_SIGNAL#SIG}" "$target"
    # Even a successful child must not turn the interrupted gate into a pass.
    exit 0
fi
if [[ "$name" == xcrun ]]; then
    for arg in "$@"; do
        if [[ "$arg" == --json ]]; then printf '{"targets": []}\n'; exit 0; fi
    done
    printf 'fixture coverage\n'
fi
"""


class VerificationTests(unittest.TestCase):
    # Every case has its own temp repository/env; signal targets are new sessions, never this runner.
    parallel_safe = True

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Can I Wear tooling ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(SCRIPT, self.root / "scripts/verify.sh")
        (self.root / "Can I Wear").mkdir()
        (self.root / "Can I Wear/Root.plist").write_text("fixture")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in TOOLS:
            tool = self.bin / name
            tool.write_text(FAKE_TOOL)
            tool.chmod(0o755)
        self.calls_file = self.root / "calls.bin"
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
                        TOOL_CALLS=str(self.calls_file))
        for name in ("FAIL_TOOL", "VERIFY_DESTINATION", "INTERRUPT_TOOL",
                     "INTERRUPT_SIGNAL", "INTERRUPT_TARGET", "VERIFY_PERFORMANCE_BASELINE"):
            self.env.pop(name, None)

    def verify(self, *args, fail_tool=None):
        if fail_tool:
            self.env["FAIL_TOOL"] = fail_tool
        return subprocess.run(
            ["/bin/bash", str(self.root / "scripts/verify.sh"), *args],
            cwd="/", env=self.env, text=True, capture_output=True, timeout=30,
            start_new_session=True,
        )

    def calls(self, name):
        if not self.calls_file.exists():
            return []
        fields = iter(self.calls_file.read_text().split("\0")[:-1])
        calls = []
        for tool in fields:
            args = [next(fields) for _ in range(int(next(fields)))]
            if tool == name:
                calls.append(args)
        return calls

    def test_docs_checks_both_diffs_without_native_tools(self):
        result = self.verify("docs")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls("git"), [["diff", "--check"], ["diff", "--cached", "--check"]])
        self.assertEqual(self.calls("swiftlint"), [])
        self.assertEqual(self.calls("xcodebuild"), [])

    def test_default_runs_unit_tests_with_coverage_and_strict_warnings(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)
        command = self.calls("xcodebuild")[-1]
        self.assertIn("-only-testing:Can I WearTests", command)
        self.assertIn("SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", command)
        self.assertIn("-enableCodeCoverage", command)
        self.assertIn("Can I Wear.xcodeproj", command)
        self.assertTrue(command[-1] == "test")
        self.assertEqual(len(self.calls("xcrun")), 3)
        reports = list(self.root.glob(".build/verification/code.*/coverage.json"))
        self.assertEqual(len(reports), 1)
        self.assertEqual(json.loads(reports[0].read_text()), {"targets": []})

    def test_full_builds_release_and_does_not_filter_out_ui_tests(self):
        self.env["VERIFY_DESTINATION"] = "platform=iOS Simulator,name=Fixture Phone"
        result = self.verify("full")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.calls("xcodebuild")
        self.assertIn("Release", commands[1])
        self.assertEqual(commands[1][-1], "build")
        self.assertFalse(any(arg.startswith("-only-testing") for arg in commands[2]))
        self.assertIn("-skip-testing:Can I WearUITests/LaunchPerformanceTests", commands[2])
        self.assertIn(self.env["VERIFY_DESTINATION"], commands[2])

    def test_performance_is_separate_uninstrumented_and_not_a_regression_pass_without_baseline(self):
        result = self.verify("performance")
        self.assertEqual(result.returncode, 0, result.stderr)
        command = self.calls("xcodebuild")[-1]
        self.assertIn("Debug", command)
        self.assertIn("-only-testing:Can I WearUITests/LaunchPerformanceTests", command)
        self.assertEqual(command[command.index("-enableCodeCoverage") + 1], "NO")
        self.assertEqual(command[command.index("-parallel-testing-enabled") + 1], "NO")
        self.assertFalse(any(args[-1] == "build" for args in self.calls("xcodebuild")))
        self.assertEqual(len(self.calls("xcrun")), 2)
        self.assertTrue(all(args[0] == "xcresulttool" for args in self.calls("xcrun")))
        self.assertIn("MEASURED: performance profile", result.stdout)
        self.assertNotIn("PASS: performance profile", result.stdout)
        self.assertEqual(list(self.root.glob(".build/verification/*/coverage.json")), [])

    def test_performance_comparison_forwards_baseline_and_failure_is_not_measurement_success(self):
        self.env["VERIFY_PERFORMANCE_BASELINE"] = "/fixture with spaces/baseline.json"
        result = self.verify("performance")
        self.assertEqual(result.returncode, 0, result.stderr)
        comparison = self.calls("python3")[-1]
        self.assertEqual(comparison[0], "scripts/check-performance.py")
        self.assertEqual(comparison[-1], self.env["VERIFY_PERFORMANCE_BASELINE"])
        self.assertIn("PASS: performance profile", result.stdout)
        result = self.verify("performance", fail_tool="xcrun")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PASS: performance profile", result.stdout)
        self.assertNotIn("MEASURED: performance profile", result.stdout)

    def test_fake_tools_preserve_arguments_and_phase_timing_is_recorded(self):
        self.env["VERIFY_DESTINATION"] = "fixture with spaces, quotes ' and \" and\nnewline"
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(self.env["VERIFY_DESTINATION"], self.calls("xcodebuild")[-1])
        timings = next(self.root.glob(".build/verification/code.*/timings.tsv")).read_text().splitlines()
        labels = []
        for row in timings:
            label, seconds, status = row.split("\t")
            labels.append(label)
            self.assertGreaterEqual(int(seconds), 0)
            self.assertEqual(int(status), 0)
        self.assertIn("tests", labels)
        self.assertIn("tooling-tests", labels)

    def test_static_does_not_claim_build_or_test_validation(self):
        result = self.verify("static")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--strict", self.calls("swiftlint")[-1])
        self.assertTrue(self.calls("shellcheck"))
        self.assertTrue(self.calls("plutil"))
        self.assertEqual(self.calls("xcodebuild"), [])

    def test_missing_tool_is_failure_not_skip(self):
        (self.bin / "swiftlint").unlink()
        result = self.verify("static")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required tool missing: swiftlint", result.stderr)
        self.assertNotIn("PASS:", result.stdout)

    def test_failures_propagate_through_log_pipeline(self):
        for tool in ("git", "shellcheck", "swiftlint", "plutil", "python3", "xcodebuild", "xcrun"):
            with self.subTest(tool=tool):
                result = self.verify(fail_tool=tool)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("PASS:", result.stdout)
                self.assertIn("FAIL: code profile", result.stderr)

    def test_lint_failure_does_not_prevent_test_evidence_but_still_fails_gate(self):
        result = self.verify(fail_tool="swiftlint")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(any(args[-1] == "test" for args in self.calls("xcodebuild")))
        self.assertTrue(self.calls("xcrun"))
        self.assertIn("FAIL: code profile", result.stderr)

    def test_test_failure_does_not_produce_successful_run_coverage(self):
        result = self.verify(fail_tool="xcodebuild")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("xcrun"), [])
        self.assertEqual(list(self.root.glob(".build/verification/code.*/coverage.json")), [])

    def test_interruption_never_reports_pass_or_collects_coverage(self):
        for profile, tool in (("docs", "git"), ("static", "swiftlint"),
                              ("code", "xcodebuild"), ("full", "xcodebuild"), ("performance", "xcodebuild")):
            for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
                for target in ("parent", "group"):
                    with self.subTest(profile=profile, signal=signum.name, target=target):
                        self.calls_file.unlink(missing_ok=True)
                        self.env.update(INTERRUPT_TOOL=tool, INTERRUPT_SIGNAL=signum.name,
                                        INTERRUPT_TARGET=target)
                        result = self.verify(profile)
                        self.assertEqual(result.returncode, 128 + signum, result.stdout + result.stderr)
                        self.assertNotIn("PASS:", result.stdout + result.stderr)
                        statuses = list(self.root.glob(f".build/verification/{profile}.*/status.txt"))
                        self.assertTrue(statuses)
                        for status in statuses:
                            self.assertIn(f"FAIL: {profile} profile", status.read_text())
                            self.assertNotIn("PASS:", status.read_text())
                        self.assertEqual(self.calls("xcrun"), [])
                        self.assertEqual(list(self.root.glob(".build/verification/*/coverage.json")), [])

    def test_invalid_arguments_fail_and_help_has_no_side_effects(self):
        for args in (("unknown",), ("code", "extra")):
            self.assertEqual(self.verify(*args).returncode, 2)
        self.assertEqual(self.verify("--help").returncode, 0)
        self.assertFalse((self.root / ".build").exists())


if __name__ == "__main__":
    unittest.main()
