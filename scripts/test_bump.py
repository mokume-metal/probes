"""bump.py が引数を版として検めるかを確かめる (何も書き換えず、swift も要らない)。

    python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import contextlib
import io
import pathlib
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bump  # noqa: E402


def untouched(*_args, **_kwargs):
    raise AssertionError("版として検める前に書き換え・解決へ進んだ")


@mock.patch.object(bump, "rewrite", untouched)
@mock.patch.object(bump.subprocess, "run", untouched)
class Main(unittest.TestCase):
    def test_help_prints_usage_and_writes_nothing(self):
        for flag in ("--help", "-h"):
            out = io.StringIO()
            with self.subTest(flag=flag), contextlib.redirect_stdout(out):
                self.assertEqual(bump.main([flag]), 0)
                self.assertIn("python3 scripts/bump.py 0.7.0", out.getvalue())

    def test_rejects_what_is_not_a_version(self):
        for arg in ("--dry-run", "0.11", "0.11.2.1", "latest", "v0.11.2-beta", " 0.11.2", ""):
            with self.subTest(arg=arg), self.assertRaises(SystemExit) as raised:
                bump.main([arg, "Probe"])
            self.assertIn("版ではない", str(raised.exception.code))

    def test_no_argument_prints_usage(self):
        with self.assertRaises(SystemExit) as raised:
            bump.main([])
        self.assertIn("python3 scripts/bump.py 0.7.0", str(raised.exception.code))


class VersionOf(unittest.TestCase):
    def test_accepts_with_or_without_v(self):
        self.assertEqual(bump.version_of("0.11.2"), "0.11.2")
        self.assertEqual(bump.version_of("v0.11.2"), "0.11.2")
        self.assertEqual(bump.version_of("v10.0.12"), "10.0.12")


if __name__ == "__main__":
    unittest.main()
