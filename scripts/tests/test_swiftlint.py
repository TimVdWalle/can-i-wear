"""Check that the actual lint configuration accepts clean code and catches defects."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


CONFIG = Path(__file__).resolve().parents[2] / ".swiftlint.yml"


class SwiftLintConfigurationTests(unittest.TestCase):
    def lint(self, source):
        with tempfile.TemporaryDirectory(prefix="Can I Wear lint ") as directory:
            root = Path(directory)
            shutil.copy2(CONFIG, root / ".swiftlint.yml")
            (root / "Can I Wear").mkdir()
            (root / "Can I Wear/Probe.swift").write_text(source)
            return subprocess.run(
                ["swiftlint", "lint", "--config", ".swiftlint.yml", "--strict", "--no-cache"],
                cwd=root, text=True, capture_output=True, timeout=30,
            )

    def test_clean_code_passes(self):
        result = self.lint("func name(_ value: Any) -> String? { value as? String }\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_necessary_nested_optional_flattening_is_not_flagged(self):
        result = self.lint(
            "extension Array {\n"
            "subscript(safe index: Index) -> Element? {\n"
            "indices.contains(index) ? self[index] : nil\n}\n}\n"
            "let values: [Double?]? = [nil, 1]\n"
            "let flattened: Double? = values?[safe: 0] ?? nil\n"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unsafe_cast_and_try_are_detected(self):
        result = self.lint(
            "func name(_ value: Any) -> String { value as! String }\n"
            "func load() throws -> String { return \"fixture\" }\n"
            "let value = try! load()\n"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("force_cast", result.stdout)
        self.assertIn("force_try", result.stdout)

    def test_excessive_complexity_is_detected(self):
        branches = "".join(f"if value == {number} {{ return {number} }}\n" for number in range(15))
        result = self.lint(f"func classify(_ value: Int) -> Int {{\n{branches}return -1\n}}\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cyclomatic_complexity", result.stdout)


if __name__ == "__main__":
    unittest.main()
