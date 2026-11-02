"""Exercise benchmark reporting/comparison without a simulator or real timing dependencies."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("performance", Path(__file__).resolve().parents[1] / "check-performance.py")
performance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(performance)


class PerformanceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="Can I Wear performance ")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.summary = {
            "result": "Passed", "failedTests": 0, "skippedTests": 0,
            "environmentDescription": "fixture macOS",
            "devicesAndConfigurations": [{"device": {
                "deviceId": "fixture", "modelName": "Fixture Phone", "osBuildNumber": "123",
                "architecture": "arm64", "platform": "iOS Simulator",
            }}],
        }
        self.metrics = [{
            "testIdentifier": performance.TEST,
            "testRuns": [{"device": {"deviceId": "fixture"}, "metrics": [
                {"identifier": "ApplicationLaunch", "measurements": [2.0] * 5,
                 "unitOfMeasurement": "s", "polarity": "prefers smaller"},
                {"identifier": "Clock", "measurements": [3.0] * 5,
                 "unitOfMeasurement": "s", "polarity": "prefers smaller"},
            ]}],
        }]
        (self.root / "xcode-version.log").write_text("fixture Xcode")

    def report(self, baseline=None):
        (self.root / "performance-summary.log").write_text(json.dumps(self.summary))
        (self.root / "performance-metrics.log").write_text(json.dumps(self.metrics))
        with contextlib.redirect_stdout(io.StringIO()):
            return performance.report(self.root, baseline)

    def baseline(self):
        path = self.root / "baseline.json"
        path.write_text(json.dumps(self.report()))
        return path

    def test_no_baseline_reports_measurement_not_regression_pass(self):
        result = self.report()
        self.assertEqual(result["outcome"], "measured")
        self.assertEqual(result["metrics"]["Clock"]["mean_seconds"], 3)
        self.assertEqual(json.loads((self.root / "performance.json").read_text()), result)

    def test_matching_baseline_passes_and_regression_fails_for_either_metric(self):
        path = self.baseline()
        self.assertEqual(self.report(path)["outcome"], "passed")
        original = copy.deepcopy(self.metrics)
        for index in (0, 1):
            with self.subTest(metric=index):
                self.metrics = copy.deepcopy(original)
                metric = self.metrics[0]["testRuns"][0]["metrics"][index]
                metric["measurements"] = [value * 1.11 for value in metric["measurements"]]
                with self.assertRaisesRegex(ValueError, "regression"):
                    self.report(path)
                self.assertEqual(json.loads((self.root / "performance.json").read_text())["outcome"], "failed")

    def test_incompatible_or_missing_baseline_is_not_silently_accepted(self):
        path = self.baseline()
        self.summary["devicesAndConfigurations"][0]["device"]["osBuildNumber"] = "different"
        with self.assertRaisesRegex(ValueError, "Incompatible baseline"):
            self.report(path)
        with self.assertRaises(OSError):
            self.report(self.root / "missing.json")

    def test_empty_missing_duplicate_invalid_and_unstable_metrics_fail(self):
        original = copy.deepcopy(self.metrics)
        for values in ([], [1], [0] * 5, [-1] * 5, [float("nan")] * 5,
                       [float("inf")] * 5, [True] * 5, [1, 1, 1, 1, 10]):
            with self.subTest(values=values):
                self.metrics = copy.deepcopy(original)
                self.metrics[0]["testRuns"][0]["metrics"][0]["measurements"] = values
                with self.assertRaises(ValueError):
                    self.report()
        self.metrics = []
        with self.assertRaises(ValueError):
            self.report()
        self.metrics = original * 2
        with self.assertRaises(ValueError):
            self.report()

    def test_skipped_failed_or_multiple_device_runs_are_rejected(self):
        for key, value in (("result", "Failed"), ("failedTests", 1), ("skippedTests", 1),
                           ("devicesAndConfigurations", self.summary["devicesAndConfigurations"] * 2)):
            with self.subTest(key=key):
                original = self.summary[key]
                self.summary[key] = value
                with self.assertRaises(ValueError):
                    self.report()
                self.summary[key] = original

    def test_unstable_baseline_and_unknown_units_fail(self):
        path = self.baseline()
        baseline = json.loads(path.read_text())
        baseline["metrics"]["Clock"]["relative_stddev"] = 0.2
        path.write_text(json.dumps(baseline))
        with self.assertRaisesRegex(ValueError, "unstable baseline"):
            self.report(path)
        self.metrics[0]["testRuns"][0]["metrics"][0]["unitOfMeasurement"] = "ms"
        with self.assertRaisesRegex(ValueError, "units"):
            self.report()

    def test_failed_benchmark_cannot_become_the_baseline(self):
        path = self.baseline()
        baseline = json.loads(path.read_text())
        baseline["outcome"] = "failed"
        path.write_text(json.dumps(baseline))
        with self.assertRaisesRegex(ValueError, "failed benchmark"):
            self.report(path)


if __name__ == "__main__":
    unittest.main()
