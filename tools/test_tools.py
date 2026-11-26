"""Unit tests for tools/*.py helpers that CI depends on.

Run: python3 -m pytest tools/test_tools.py  (or unittest)
"""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, ROOT / "tools" / f"{name}.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestCheckStrings(unittest.TestCase):
    def test_quote_problem_balanced(self):
        mod = load("check_strings")
        self.assertIsNone(mod.quote_problem("'hello'"))
        self.assertIsNotNone(mod.quote_problem("'hello"))

    def test_strip_comment_keeps_slashes_in_string(self):
        mod = load("check_strings")
        self.assertIn("https://", mod.strip_comment("'https://x' // hi"))


class TestAuditContrast(unittest.TestCase):
    def test_relative_luminance_black_white(self):
        mod = load("audit_contrast")
        # Black luminance 0, white 1 (WCAG formula).
        self.assertAlmostEqual(mod.relative_luminance((0, 0, 0)), 0.0)
        self.assertAlmostEqual(mod.relative_luminance((255, 255, 255)), 1.0)

    def test_contrast_ratio_black_white_is_21(self):
        mod = load("audit_contrast")
        ratio = mod.contrast_ratio((0, 0, 0), (255, 255, 255))
        self.assertAlmostEqual(ratio, 21.0, places=1)


class TestAnnotateCi(unittest.TestCase):
    def test_escape(self):
        mod = load("annotate_ci")
        self.assertEqual(mod.escape("a%b\nc"), "a%25b%0Ac")


if __name__ == "__main__":
    unittest.main()
