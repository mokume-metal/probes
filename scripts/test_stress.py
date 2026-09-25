"""stress.py の読み取りと判定を確かめる (GPU も swift も要らない)。

    python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import stress  # noqa: E402

# swift-testing が実際に書いた最後の行 (Probe で採った)
PASSED = "􀢂  Test run with 13 tests in 1 suite passed after 0.268 seconds with 21 known issues."
FAILED = "􀢄  Test run with 13 tests in 1 suite failed after 0.270 seconds with 22 issues (including 21 known issues)."
PASSED_CLEAN = "􁁛  Test run with 1 test in 1 suite passed after 0.1 seconds."


class ParseSummary(unittest.TestCase):
    def test_passed_with_known_issues(self):
        self.assertEqual(stress.parse_summary("前置き\n" + PASSED), stress.Summary(13, True, 21))

    def test_failed_reads_known_not_total(self):
        self.assertEqual(stress.parse_summary(FAILED), stress.Summary(13, False, 21))

    def test_single_test_without_known_issues(self):
        self.assertEqual(stress.parse_summary(PASSED_CLEAN), stress.Summary(1, True, 0))

    def test_missing_line(self):
        self.assertIsNone(stress.parse_summary("Building...\nerror: Exited with unexpected signal code 11"))

    def test_last_line_wins(self):
        self.assertEqual(stress.parse_summary(PASSED + "\n" + FAILED).passed, False)


class Classify(unittest.TestCase):
    def test_pass(self):
        self.assertEqual(stress.classify(0, False, PASSED, 21), stress.PASS)

    def test_timeout_is_hang(self):
        self.assertEqual(stress.classify(None, True, PASSED, 21), stress.HANG)

    def test_signal_is_crash(self):
        self.assertEqual(stress.classify(-11, False, "", 21), stress.CRASH)

    def test_helper_signal_is_crash(self):
        output = PASSED + "\nerror: Exited with unexpected signal code 6"
        self.assertEqual(stress.classify(1, False, output, 21), stress.CRASH)

    def test_no_summary_is_crash(self):
        self.assertEqual(stress.classify(1, False, "途中まで", 21), stress.CRASH)

    def test_failed(self):
        self.assertEqual(stress.classify(1, False, FAILED, 21), stress.FAIL)

    def test_nonzero_exit_with_passed_line_is_fail(self):
        self.assertEqual(stress.classify(1, False, PASSED, 21), stress.FAIL)

    def test_known_count_moved(self):
        self.assertEqual(stress.classify(0, False, PASSED, 20), stress.KNOWN_DRIFT)

    def test_no_baseline(self):
        self.assertEqual(stress.classify(0, False, PASSED, None), stress.PASS)


class Prints(unittest.TestCase):
    def test_read_merges_processes_and_keeps_duplicates(self):
        with tempfile.TemporaryDirectory() as d:
            (pathlib.Path(d) / "Probe-1.tsv").write_text("a-suspect\t2\tbb\na-suspect\t2\taa\n")
            (pathlib.Path(d) / "Probe-2.tsv").write_text("grid\t1\tcc\n\n")
            self.assertEqual(
                stress.read_prints(pathlib.Path(d)),
                {("a-suspect", 2): ("aa", "bb"), ("grid", 1): ("cc",)},
            )

    def test_all_equal(self):
        prints = {("a", 1): ("x",), ("a", 2): ("y",)}
        self.assertEqual(stress.compare_prints({"plain#0": prints, "plain#1": dict(prints)}), [])

    def test_one_frame_differs(self):
        base = {("a", 1): ("x",), ("a", 2): ("y",)}
        odd = {("a", 1): ("x",), ("a", 2): ("z",)}
        mismatches = stress.compare_prints({"plain#0": base, "plain#1": base, "validation#0": odd})
        self.assertEqual(mismatches, [stress.Mismatch(("a", 2), 2, ["validation#0"])])

    def test_missing_in_one_run(self):
        base = {("a", 1): ("x",), ("b", 1): ("y",)}
        mismatches = stress.compare_prints({"plain#0": base, "plain#1": base, "contention#3": {("a", 1): ("x",)}})
        self.assertEqual(mismatches, [stress.Mismatch(("b", 1), 2, ["contention#3"])])

    def test_duplicate_draws_compare_as_multiset(self):
        # 同じ名前を 2 度描く検査は、描いた順が実行ごとに入れ替わっても同じとみなす
        a = stress.read_prints_from_lines(["n\t1\tp", "n\t1\tq"])
        b = stress.read_prints_from_lines(["n\t1\tq", "n\t1\tp"])
        self.assertEqual(stress.compare_prints({"r0": a, "r1": b}), [])

    def test_single_run_cannot_mismatch(self):
        self.assertEqual(stress.compare_prints({"plain#0": {("a", 1): ("x",)}}), [])


class Overlap(unittest.TestCase):
    def test_overlap(self):
        self.assertEqual(stress.max_overlap([(0, 10), (1, 5), (2, 3), (11, 12)]), 3)

    def test_touching_spans_do_not_overlap(self):
        self.assertEqual(stress.max_overlap([(0, 1), (1, 2)]), 1)

    def test_empty(self):
        self.assertEqual(stress.max_overlap([]), 0)


if __name__ == "__main__":
    unittest.main()
