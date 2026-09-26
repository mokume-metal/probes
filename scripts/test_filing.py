"""filing.py が起票の骨格と再現のファイルを検めるかを確かめる (gh も swift も叩かない)。

    python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import contextlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import filing  # noqa: E402

SHA = "0123456789abcdef0123456789abcdef01234567"

GOOD = f"""前置き (区間の外は検めない)

<!-- probes-filing:begin v1 -->
## 事象

`beginShape()` の折れ線の折れ目が、帯の外へはみ出す。

## 再現

```swift
enum PolylineJoin {{}}
```

## 期待と実際

期待は `line()` と同じ形。実際は 38 画素違う。

## 証跡

![polylineJoin](https://github.com/user-attachments/assets/bed80fce)

## 確かめたこと

- 単独の再現: 出る
- main: 出る (mokume main `300960c`)
- 反復: 同じ機械で 5 回・毎回同じ
- 陰性対照・境界: `.blend` では 0 画素
- 重複: 「polyline join」で検索し、同じ根は無い

## 当たり (`v0.12.0`)

`Sources/MokumeCore/Drawing/Canvas+Outline.swift:282`

## 出どころ

[`polylineJoin`](https://github.com/mokume-metal/probes/blob/{SHA}/Weave/Tests/WeaveTests/Repros/polylineJoin.swift)

## 環境

| 項目 | 値 |
|---|---|
| macOS | 27.0 (27A5) |
| チップ | Apple M3 Max |
| Xcode | Xcode 27.0 / 27A100 |
| Swift | swift-driver version: 1.200 |
| mokume | `v0.12.0` (`bab3b4a`) |
| 組み方 | debug |
<!-- probes-filing:end -->

## 現況 (トリアージが後から足す)

<!-- 書く: 区間の外なら残っていてよい -->
"""

TITLE = "fix(stroke): `beginShape()` の太い折れ線の折れ目が帯の外へはみ出す"


def section(name: str) -> tuple[int, int]:
    """GOOD の中の `## name` の区間 (見出しから次の見出しの手前まで)。"""
    start = GOOD.index(f"## {name}")
    ends = [GOOD.index(m, start + 1) for m in ("\n## ", "\n<!-- probes-filing:end") if m in GOOD[start + 1:]]
    return start, min(ends)


def without(name: str) -> str:
    start, end = section(name)
    return GOOD[:start] + GOOD[end + 1:]


class CheckBody(unittest.TestCase):
    def test_good_body_passes(self):
        self.assertEqual(filing.check_body(GOOD, TITLE), [])

    def test_each_missing_section_fails(self):
        for name in filing.SECTIONS:
            with self.subTest(section=name):
                problems = filing.check_body(without(name))
                self.assertTrue(any(f"## {name}" in p for p in problems), problems)

    def test_heading_matches_by_prefix(self):
        self.assertIn("## 当たり (`v0.12.0`)", GOOD)
        self.assertEqual(filing.check_body(GOOD), [])

    def test_missing_or_doubled_markers_fail(self):
        for body in (GOOD.replace(filing.BEGIN, ""), GOOD.replace(filing.END, ""), GOOD + filing.BEGIN):
            with self.subTest(body=body[-40:]):
                self.assertIn("区間の印", filing.check_body(body)[0])

    def test_unfilled_field_inside_region_fails(self):
        body = GOOD.replace("期待は `line()` と同じ形。", "<!-- 書く: 期待 -->")
        self.assertTrue(any("埋めていない" in p for p in filing.check_body(body)))

    def test_unfilled_field_outside_region_passes(self):
        self.assertIn("<!-- 書く:", GOOD.split(filing.END)[1])
        self.assertEqual(filing.check_body(GOOD), [])

    def test_repro_without_swift_fails(self):
        body = GOOD.replace("```swift\nenum", "```\nenum")
        self.assertTrue(any("swift のコード" in p for p in filing.check_body(body)))

    def test_evidence_needs_attachment_or_reason(self):
        image = "![polylineJoin](https://github.com/user-attachments/assets/bed80fce)"
        cases = {
            image.replace("github.com/user-attachments", "i.gyazo.com"): False,
            "不要:": False,
            "不要: 画素に出ない (落ちる事象)": True,
        }
        for evidence, passes in cases.items():
            with self.subTest(evidence=evidence):
                problems = filing.check_body(GOOD.replace(image, evidence))
                self.assertEqual(not any("## 証跡" in p for p in problems), passes, problems)

    def test_source_needs_commit_pinned_blob(self):
        for link in ("https://github.com/mokume-metal/probes/blob/main/",
                     "https://github.com/mokume-metal/probes/pull/38/"):
            with self.subTest(link=link):
                body = GOOD.replace(f"https://github.com/mokume-metal/probes/blob/{SHA}/", link)
                self.assertTrue(any("## 出どころ" in p for p in filing.check_body(body)))

    def test_each_environment_key_is_required(self):
        for key in filing.ENV_KEYS:
            with self.subTest(key=key):
                row = next(line for line in GOOD.splitlines() if line.startswith(f"| {key} |"))
                for body in (GOOD.replace(row + "\n", ""), GOOD.replace(row, f"| {key} |  |")):
                    self.assertTrue(any(f"`{key}`" in p for p in filing.check_body(body)))

    def test_each_checked_item_is_required(self):
        for item in filing.CHECKED:
            with self.subTest(item=item):
                line = next(x for x in GOOD.splitlines() if x.startswith(f"- {item}:"))
                self.assertTrue(any(f"`- {item}: …`" in p for p in filing.check_body(GOOD.replace(line, ""))))

    def test_unconfirmed_needs_reason(self):
        line = "- main: 出る (mokume main `300960c`)"
        cases = {"- main: 未確認": False, "- main: 未確認:": False, "- main: 未確認: main が組めない (#1700)": True}
        for replacement, passes in cases.items():
            with self.subTest(line=replacement):
                problems = filing.check_body(GOOD.replace(line, replacement))
                self.assertEqual(not any("`- main`" in p for p in problems), passes, problems)

    def test_title_needs_identifier(self):
        self.assertEqual(filing.check_body(GOOD, TITLE), [])
        problems = filing.check_body(GOOD, "fix(stroke): 太い折れ線の折れ目が帯の外へはみ出す")
        self.assertTrue(any("タイトル" in p for p in problems))

    def test_heading_inside_code_fence_is_not_a_section(self):
        # 証跡の区間を消し、再現のコードの中に証跡らしい行を置く。コードの中は見出しに数えない
        fenced = "enum PolylineJoin {}\n## 証跡\n// https://github.com/user-attachments/assets/x"
        body = without("証跡").replace("enum PolylineJoin {}", fenced)
        self.assertTrue(any("## 証跡" in p for p in filing.check_body(body)))


REPRO = """// repro: mokume#1644
import Foundation
import mokume

enum PolylineJoin {
    static func reproduce() throws -> String? { nil }
}
"""


class LintRepro(unittest.TestCase):
    def test_self_contained_repro_passes(self):
        self.assertEqual(filing.lint_repro(REPRO), ("PolylineJoin", "1644", []))

    def test_not_filed_yet_is_a_valid_mark(self):
        self.assertEqual(filing.lint_repro(REPRO.replace("1644", "未起票"))[1], "未起票")

    def test_broken_promises_fail(self):
        cases = {
            "1 行目": REPRO.replace("// repro: mokume#1644", "// mokume#1644"),
            "import Testing": REPRO.replace("import Foundation", "import Testing"),
            "@testable": REPRO.replace("import Foundation", "@testable import Weave"),
            "`enum` が 2 個": REPRO + "enum Other {}\n",
            "reproduce": REPRO.replace("-> String?", "-> Bool"),
        }
        for expected, text in cases.items():
            with self.subTest(case=expected):
                self.assertTrue(any(expected in p for p in filing.lint_repro(text)[2]), filing.lint_repro(text)[2])


class CheckAll(unittest.TestCase):
    """仮の probes を組み、名指し・台帳・再現・gh の本文を突き合わせる。"""

    def setUp(self):
        self.root = pathlib.Path(self.enter(tempfile.TemporaryDirectory()))
        tests = self.root / "Weave" / "Tests" / "WeaveTests"
        (tests / "Repros").mkdir(parents=True)
        (self.root / "Weave" / "Package.swift").write_text("")
        (self.root / "docs").mkdir()
        (tests / "WeaveTests.swift").write_text(
            'try compareKnown(.a, "mokume#1643: 既存")\n'
            'withKnownIssue("mokume#1644: 新しい") {}\n'
            'withKnownIssue("mokume#1644: 同じ番号をもう 1 か所") {}\n')
        (tests / "Repros" / "polylineJoin.swift").write_text(REPRO)
        self.enter(mock.patch.object(filing, "ROOT", self.root))
        self.enter(mock.patch.object(filing.pieces, "ROOT", self.root))
        self.enter(mock.patch.object(filing, "BASELINE", self.root / "docs" / "filing-baseline.txt"))
        self.baseline("1643  # Weave\n")
        self.issues = {1644: {"title": TITLE, "body": GOOD}}
        self.enter(mock.patch.object(filing.subprocess, "run", self.gh))

    def enter(self, manager):
        """`enterContext` (3.11) の代わり。macOS 標準の python3 は 3.9 (#13)。"""
        value = manager.__enter__()
        self.addCleanup(manager.__exit__, None, None, None)
        return value

    def baseline(self, text: str):
        (self.root / "docs" / "filing-baseline.txt").write_text("# 台帳\n" + text)

    def gh(self, command, **_kwargs):
        self.assertEqual(command[:2], ["gh", "api"], "gh api 以外を呼んだ")
        number = int(command[2].rsplit("/", 1)[1])
        if number not in self.issues:
            return subprocess.CompletedProcess(command, 1, "", "HTTP 404: Not Found")
        return subprocess.CompletedProcess(command, 0, json.dumps(self.issues[number]), "")

    def run_check(self) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = filing.check_all()
        return code, out.getvalue()

    def test_named_collects_every_form_once(self):
        self.assertEqual(filing.named(), {1643: {"Weave"}, 1644: {"Weave"}})

    def test_passes_when_new_filing_follows_skeleton(self):
        self.assertEqual(self.run_check(), (0, ""))

    def test_baseline_exempts_old_filings(self):
        self.baseline("")
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("mokume#1643 (Weave): 再現のファイル", out)

    def test_new_filing_without_skeleton_fails(self):
        self.issues[1644]["body"] = "## 事象\n\n雑なメモ"
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("mokume#1644 (Weave): 区間の印", out)

    def test_new_filing_without_repro_fails(self):
        (self.root / "Weave/Tests/WeaveTests/Repros/polylineJoin.swift").unlink()
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("mokume#1644 (Weave): 再現のファイル (`// repro: mokume#1644`) が無い", out)

    def test_unfiled_repro_fails(self):
        (self.root / "Weave/Tests/WeaveTests/Repros/other.swift").write_text(
            REPRO.replace("1644", "未起票").replace("PolylineJoin", "Other"))
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("起票してから入れる", out)

    def test_repro_naming_issue_nobody_tests_fails(self):
        (self.root / "Weave/Tests/WeaveTests/Repros/other.swift").write_text(
            REPRO.replace("1644", "1700").replace("PolylineJoin", "Other"))
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("mokume#1700 を名指しする検査", out)

    def test_unreachable_issue_fails(self):
        del self.issues[1644]
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("引けない: HTTP 404", out)


if __name__ == "__main__":
    unittest.main()
