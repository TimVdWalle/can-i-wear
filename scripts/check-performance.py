"""Validate fixture launch metrics; never mistake an unbaselined measurement for a regression pass."""

import json
import math
from pathlib import Path
import platform
import statistics
import sys


TEST = "LaunchPerformanceTests/testLaunchToRecommendationReady()"
TOLERANCE = 0.10  # Development measurement tolerance, not a product startup target.


def read(path):
    return json.loads(path.read_text())


def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def report(directory, baseline_path=None):
    summary = read(directory / "performance-summary.log")
    if summary["result"] != "Passed" or summary["failedTests"] or summary["skippedTests"]:
        raise ValueError("The benchmark test must execute and pass without skips")
    configurations = summary["devicesAndConfigurations"]
    if len(configurations) != 1:
        raise ValueError("Benchmark exactly one simulator/configuration at a time")
    device = configurations[0]["device"]
    context = {
        "host": platform.node(),
        "architecture": platform.machine(),
        "environment": summary["environmentDescription"],
        "xcode": (directory / "xcode-version.log").read_text().strip(),
        "device": {key: device[key] for key in (
            "deviceId", "modelName", "osBuildNumber", "architecture", "platform")},
        "configuration": "Debug; coverage off; portrait; text Large; responsive launch + periods compact hero; XCTest default iterations",
    }
    tests = read(directory / "performance-metrics.log")
    if len(tests) != 1 or tests[0]["testIdentifier"] != TEST or len(tests[0]["testRuns"]) != 1:
        raise ValueError("Missing, duplicate or unexpected benchmark runs")
    run = tests[0]["testRuns"][0]
    if run["device"]["deviceId"] != device["deviceId"]:
        raise ValueError("Metric and summary devices differ")
    metrics = {}
    for metric in run["metrics"]:
        values = metric["measurements"]
        identifier = metric["identifier"]
        if identifier in metrics or len(values) < 5 or not all(map(positive, values)):
            raise ValueError("Need unique metrics with at least five finite positive measurements")
        if metric["unitOfMeasurement"] != "s" or metric["polarity"] != "prefers smaller":
            raise ValueError("Unexpected benchmark metric units or direction")
        mean = statistics.mean(values)
        metrics[identifier] = {
            "mean_seconds": mean, "relative_stddev": statistics.stdev(values) / mean,
            "measurements": values,
        }
    if (len(metrics) != 2 or not any("ApplicationLaunch" in key for key in metrics)
            or not any("Clock" in key for key in metrics)):
        raise ValueError("Need both application-launch and launch-to-ready clock metrics")

    result = {"test": TEST, "context": context, "tolerance": TOLERANCE, "metrics": metrics}
    errors = []
    for identifier, metric in metrics.items():
        print(f"{identifier}: {metric['mean_seconds']:.3f}s mean; {metric['relative_stddev']:.1%} RSD")
        if metric["relative_stddev"] > TOLERANCE:
            errors.append(f"Unstable measurements: {identifier}")
    if baseline_path is not None:
        baseline = read(baseline_path)
        if baseline["outcome"] not in ("measured", "passed"):
            raise ValueError("A failed benchmark cannot be used as the baseline")
        if baseline["test"] != TEST or baseline["context"] != context or baseline["metrics"].keys() != metrics.keys():
            raise ValueError("Incompatible baseline: host, Xcode, simulator/runtime or benchmark configuration differs")
        for identifier, metric in metrics.items():
            previous = baseline["metrics"][identifier]
            mean = previous["mean_seconds"]
            if not positive(mean) or not 0 <= previous["relative_stddev"] <= TOLERANCE:
                raise ValueError("Invalid or unstable baseline")
            change = metric["mean_seconds"] / mean - 1
            print(f"{identifier}: {change:+.1%} versus baseline")
            if change > TOLERANCE:
                errors.append(f"Launch regression above {TOLERANCE:.0%}: {identifier}")
    result["outcome"] = "failed" if errors else "passed" if baseline_path else "measured"
    (directory / "performance.json").write_text(json.dumps(result, indent=2, allow_nan=False) + "\n")
    if errors:
        raise ValueError("; ".join(errors))
    print("PASS: benchmark comparison" if baseline_path else "MEASURED only: no regression baseline supplied")
    return result


if __name__ == "__main__":
    try:
        if len(sys.argv) not in (2, 3):
            raise ValueError("Usage: check-performance.py RUN_DIRECTORY [BASELINE_JSON]")
        report(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) == 3 else None)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
