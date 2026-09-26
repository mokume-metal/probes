#!/usr/bin/env python3
"""mokume への起票を、走らせたものから組み、骨格を検める (docs/filing.md・ADR-0012)。

    python3 scripts/filing.py env Weave                      # 環境の表
    python3 scripts/filing.py repro Weave polylineJoin       # 再現を単独のパッケージで走らせる
    python3 scripts/filing.py repro Weave polylineJoin --mokume main
    python3 scripts/filing.py draft Weave polylineJoin --shot <URL> > draft.md
    python3 scripts/filing.py check --body draft.md --title "fix(stroke): …"
    python3 scripts/filing.py check                          # CI: 名指しした起票を全部

**本文に載せるものは、人が書き写さない。** 再現は `<物差し>/Tests/<物差し>Tests/Repros/<鍵>.swift`
を、検査 (`ReprosTests`) が走らせるのと同じ中身のまま貼る。環境と出どころのリンクも
ここが出す。人や AI が書くのは `<!-- 書く: … -->` の欄 (事象・期待・当たり・判断) だけ。

**検めるのは印で囲んだ区間だけ**である。区間の後ろには、mokume 側のトリアージが書き足して
よい。起票したときの報告と、後の判断を読み分けるためである (probes#43)。

**既存の起票は台帳 (`docs/filing-baseline.txt`) で猶予する。** この骨格より前に起票したもの
で、骨格へ移したら台帳から外す。

`scripts/` の多くは mokume-metal/works の写しだが、これは起票をする probes だけのもの。
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pieces  # noqa: E402

ROOT = pieces.ROOT
BASELINE = ROOT / "docs" / "filing-baseline.txt"
BLOB_BASE = "https://github.com/mokume-metal/probes/blob"

BEGIN = "<!-- probes-filing:begin v1 -->"
END = "<!-- probes-filing:end -->"
TODO = "<!-- 書く:"
SECTIONS = ["事象", "再現", "期待と実際", "証跡", "確かめたこと", "当たり", "出どころ", "環境"]
CHECKED = ["単独の再現", "main", "反復", "陰性対照・境界", "重複"]
ENV_KEYS = ["macOS", "チップ", "Xcode", "Swift", "mokume", "組み方"]

NAMED = re.compile(r'"mokume#(\d+)')
MARK = re.compile(r"^// repro: mokume#(\d+|未起票)\s*$")
IMPORT = re.compile(r"^\s*(?:@\w+\s+)*import\s+(\w+)", re.M)
ENUM = re.compile(r"^enum (\w+)", re.M)
REPRODUCE = re.compile(r"static func reproduce\(\) throws -> String\?")
BLOB = re.compile(r"https://github\.com/mokume-metal/probes/blob/[0-9a-f]{40}/")
ATTACHED = re.compile(r"https://github\.com/user-attachments/")
IDENTIFIER = re.compile(r"`[A-Za-z_][\w.]*(?:\([^`]*\))?`")
ALLOWED_IMPORTS = {"mokume", "Foundation"}


# MARK: - 再現のファイル

def repro_files() -> list[pathlib.Path]:
    return sorted(ROOT.glob("*/Tests/*/Repros/*.swift"))


def repro_file(ruler: str, key: str) -> pathlib.Path:
    folder = pieces.piece(ruler)
    found = sorted(folder.glob(f"Tests/*/Repros/{key}.swift"))
    if not found:
        raise SystemExit(f"{folder.name}/Tests/*/Repros/{key}.swift が無い (docs/filing.md「再現を置く」)")
    return found[0]


def lint_repro(text: str) -> tuple[str | None, str | None, list[str]]:
    """再現のファイルの約束を検める。(型の名前, 名指しした番号, 問題) を返す。

    **mokume だけで閉じていること**が要。probes の型を使うと、本文に貼っても走らない。
    """
    problems = []
    lines = text.splitlines()
    mark = MARK.match(lines[0]) if lines else None
    if not mark:
        problems.append("1 行目が `// repro: mokume#NNNN` (起票前は `mokume#未起票`) でない")
    for module in IMPORT.findall(text):
        if module not in ALLOWED_IMPORTS:
            problems.append(f"`import {module}`: 読み込んでよいのは {' と '.join(sorted(ALLOWED_IMPORTS))} だけ")
    if "@testable" in text:
        problems.append("`@testable import` を使っている (probes の型に頼ると単独では組めない)")
    enums = ENUM.findall(text)
    if len(enums) != 1:
        problems.append(f"最上位の `enum` が {len(enums)} 個ある (1 個だけ置く)")
    if len(REPRODUCE.findall(text)) != 1:
        problems.append("`static func reproduce() throws -> String?` が 1 つだけ無い")
    return (enums[0] if len(enums) == 1 else None, mark.group(1) if mark else None, problems)


# MARK: - 本文の骨格

def region(body: str) -> str | None:
    """印で囲んだ区間。印が揃っていなければ None。"""
    if body.count(BEGIN) != 1 or body.count(END) != 1:
        return None
    start, end = body.index(BEGIN) + len(BEGIN), body.index(END)
    return body[start:end] if start <= end else None


def sections(text: str) -> dict[str, str]:
    """`## 見出し` ごとの中身。見出しは先頭一致で決まった名前へ寄せる (括弧の後置きを許す)。"""
    out: dict[str, str] = {}
    current = None
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        if not in_fence and line.startswith("## "):
            heading = line[3:].strip()
            current = next((s for s in SECTIONS if heading.startswith(s)), heading)
            out.setdefault(current, "")
            continue
        if current is not None:
            out[current] += line + "\n"
    return out


def check_body(body: str, title: str | None = None) -> list[str]:
    """骨格を欠くところ。空なら通る。"""
    text = region(body)
    if text is None:
        return [f"区間の印 `{BEGIN}` と `{END}` が 1 組だけ無い"]
    problems = []
    if TODO in text:
        problems.append(f"埋めていない欄がある (`{TODO} …`)")
    found = sections(text)
    for name in SECTIONS:
        if not found.get(name, "").strip():
            problems.append(f"`## {name}` が無いか空")
    if "```swift" not in found.get("再現", ""):
        problems.append("`## 再現` に swift のコードが無い")
    evidence = found.get("証跡", "")
    if not ATTACHED.search(evidence) and not re.search(r"不要:\s*\S", evidence):
        problems.append("`## 証跡` に GitHub の添付 (user-attachments) も「不要: 理由」も無い")
    if not BLOB.search(found.get("出どころ", "")):
        problems.append("`## 出どころ` に commit で固定した probes のリンク (blob/<40 桁>/) が無い")
    for key in ENV_KEYS:
        if not re.search(rf"^\|\s*{re.escape(key)}\s*\|\s*[^|\s][^|]*\|", found.get("環境", ""), re.M):
            problems.append(f"`## 環境` の表に `{key}` の行が無いか空")
    checked = found.get("確かめたこと", "")
    for item in CHECKED:
        line = re.search(rf"^- {re.escape(item)}:(.*)$", checked, re.M)
        value = line.group(1).strip() if line else ""
        if not value:
            problems.append(f"`## 確かめたこと` に `- {item}: …` が無いか空")
        elif value.startswith("未確認") and not re.match(r"未確認:\s*\S", value):
            problems.append(f"`- {item}` が「未確認」なのに理由が無い (`未確認: 理由`)")
    if title is not None and not IDENTIFIER.search(title):
        problems.append("タイトルに API の識別子 (`…` で囲む) が無い")
    return problems


# MARK: - 名指しと台帳

def named() -> dict[int, set[str]]:
    """検査が名指ししている mokume の番号 → 物差しの名前。"""
    out: dict[int, set[str]] = {}
    for path in ROOT.glob("*/Tests/**/*.swift"):
        for number in NAMED.findall(path.read_text()):
            out.setdefault(int(number), set()).add(path.relative_to(ROOT).parts[0])
    return out


def baseline() -> set[int]:
    if not BASELINE.exists():
        return set()
    return {int(line.split("#")[0]) for line in BASELINE.read_text().splitlines()
            if line.split("#")[0].strip()}


def fetch(number: int) -> dict:
    """`upstream.py` の `fetch` と同じく gh api で引く。本文とタイトルも取る。"""
    done = subprocess.run(
        ["gh", "api", f"repos/mokume-metal/mokume/issues/{number}"],
        capture_output=True, text=True)
    if done.returncode:
        return {"error": done.stderr.strip()[:200]}
    raw = json.loads(done.stdout)
    return {"pr": raw.get("pull_request") is not None, "title": raw["title"], "body": raw.get("body") or ""}


def check_all() -> int:
    """再現のファイルの約束と、台帳の外の名指しの骨格を検める。問題があれば 1。"""
    problems: list[str] = []
    marks: dict[int, pathlib.Path] = {}
    names = named()
    for path in repro_files():
        where = path.relative_to(ROOT)
        _, mark, found = lint_repro(path.read_text())
        problems += [f"{where}: {p}" for p in found]
        if mark == "未起票":
            problems.append(f"{where}: 起票してから入れる (`mokume#未起票` のまま)")
        elif mark:
            marks[int(mark)] = path
            if int(mark) not in names:
                problems.append(f"{where}: mokume#{mark} を名指しする検査 (`withKnownIssue`) が無い")
    exempt = baseline()
    for number in sorted(set(names) - exempt):
        where = ", ".join(sorted(names[number]))
        if number not in marks:
            problems.append(f"mokume#{number} ({where}): 再現のファイル (`// repro: mokume#{number}`) が無い")
        issue = fetch(number)
        if "error" in issue:
            problems.append(f"mokume#{number} ({where}): 引けない: {issue['error']}")
            continue
        if issue["pr"]:
            problems.append(f"mokume#{number} ({where}): Issue ではなく PR")
            continue
        problems += [f"mokume#{number} ({where}): {p}" for p in check_body(issue["body"], issue["title"])]
    for line in problems:
        print(line)
    checked = len(set(names) - exempt)
    print(f"起票の骨格: 名指し {len(names)} 件 (台帳で猶予 {len(set(names) & exempt)} 件・検めた {checked} 件)・"
          f"再現 {len(repro_files())} 本・問題 {len(problems)} 件", file=sys.stderr)
    return 1 if problems else 0


# MARK: - 環境と、単独の再現

def capture(command: list[str], cwd: pathlib.Path | None = None) -> str:
    try:
        done = subprocess.run(command, capture_output=True, text=True, cwd=cwd)
    except FileNotFoundError:
        return ""
    return done.stdout.strip() if done.returncode == 0 else ""


def environment(ruler: str) -> dict[str, str]:
    folder = pieces.piece(ruler)
    pin = pieces.pinned(folder)
    xcode = capture(["xcodebuild", "-version"]).splitlines()
    swift = capture(["swift", "--version"]).splitlines()
    return {
        "macOS": f"{capture(['sw_vers', '-productVersion'])} ({capture(['sw_vers', '-buildVersion'])})",
        "チップ": capture(["sysctl", "-n", "machdep.cpu.brand_string"]),
        "Xcode": " ".join(xcode).replace("Build version", "/"),
        "Swift": swift[0] if swift else "",
        "mokume": f"`v{pin['version']}` (`{pin['revision'][:7]}`)",
        "組み方": "debug (`swift build` の既定)",
    }


def env_table(values: dict[str, str]) -> str:
    rows = [f"| {k} | {v or '取れない'} |" for k, v in values.items()]
    return "\n".join(["| 項目 | 値 |", "|---|---|", *rows])


def package_swift(ruler: str, mokume: str | None) -> str:
    if mokume:
        requirement = f'branch: "{mokume}"'
    else:
        requirement = f'exact: "{pieces.pinned(pieces.piece(ruler))["version"]}"'
    return f"""// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Repro",
    platforms: [.macOS("26.0")],
    dependencies: [.package(url: "https://github.com/mokume-metal/mokume.git", {requirement})],
    targets: [
        .executableTarget(
            name: "Repro",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)])
    ]
)
"""


def main_swift(name: str) -> str:
    return f"""import Foundation

if let broken = try {name}.reproduce() {{
    print("再現した: \\(broken)")
    exit(1)
}}
print("期待どおり")
"""


def run_repro(ruler: str, key: str, mokume: str | None) -> tuple[int, str, dict[str, str]]:
    """単独のパッケージに組んで走らせる。(終了コード, 出力, 組んだファイル) を返す。

    終了コードは 1 = 再現した・0 = 期待どおり・2 = 組めない。落ちる再現は 1 に数える。
    `.build` は mokume の参照ごとに使い回す。
    """
    path = repro_file(ruler, key)
    source = path.read_text()
    name, _, problems = lint_repro(source)
    if problems or name is None:
        raise SystemExit("\n".join(f"{path.relative_to(ROOT)}: {p}" for p in problems))
    files = {"Package.swift": package_swift(ruler, mokume),
             "Sources/Repro/main.swift": main_swift(name),
             f"Sources/Repro/{path.name}": source}
    work = ROOT / ".build" / "filing" / (mokume or f"v{pieces.pinned(pieces.piece(ruler))['version']}")
    sources = work / "Sources" / "Repro"
    if sources.exists():
        for old in sources.glob("*.swift"):
            old.unlink()
    for relative, text in files.items():
        (work / relative).parent.mkdir(parents=True, exist_ok=True)
        (work / relative).write_text(text)
    if mokume:
        subprocess.run(["swift", "package", "update"], cwd=work, capture_output=True, text=True)
    built = subprocess.run(["swift", "build"], cwd=work, capture_output=True, text=True)
    if built.returncode:
        return 2, (built.stdout + built.stderr)[-3000:], files
    ran = subprocess.run([str(work / ".build" / "debug" / "Repro")], cwd=work, capture_output=True, text=True)
    output = (ran.stdout + ran.stderr).strip()
    if ran.returncode < 0:
        return 1, f"{output}\n(シグナル {-ran.returncode} で落ちた)".strip(), files
    return (1 if ran.returncode else 0), output, files


def resolved_revision(work: pathlib.Path) -> str:
    resolved = work / "Package.resolved"
    if not resolved.exists():
        return ""
    pin = next(p for p in json.loads(resolved.read_text())["pins"] if p["identity"] == "mokume")
    return pin["state"]["revision"][:7]


# MARK: - 下書き

def head() -> tuple[str, bool]:
    """HEAD の commit と、それが origin に届いているか。"""
    sha = capture(["git", "rev-parse", "HEAD"], ROOT)
    pushed = bool(capture(["git", "branch", "-r", "--contains", sha], ROOT))
    return sha, pushed


def draft(ruler: str, key: str, shots: list[str], skip_main: bool) -> str:
    path = repro_file(ruler, key)
    relative = path.relative_to(ROOT).as_posix()
    code, output, files = run_repro(ruler, key, None)
    if code == 2:
        raise SystemExit(f"再現が組めない:\n{output}")
    if code == 0:
        raise SystemExit(f"再現が破れを出さない (期待どおりだった):\n{output}")
    version = pieces.pinned(pieces.piece(ruler))["version"]
    if skip_main:
        on_main = f"{TODO} `python3 scripts/filing.py repro {ruler} {key} --mokume main` の結果 -->"
    else:
        main_code, main_output, _ = run_repro(ruler, key, "main")
        revision = resolved_revision(ROOT / ".build" / "filing" / "main")
        verdict = {0: "出ない (main で直っている)", 1: "出る", 2: "組めない"}[main_code]
        on_main = f"{verdict} (mokume main `{revision}`)"
    sha, pushed = head()
    if not pushed:
        print(f"注意: HEAD ({sha[:7]}) が origin に無い。push してからでないと、出どころのリンクが開かない",
              file=sys.stderr)
    if capture(["git", "status", "--porcelain", "--", relative], ROOT):
        print(f"注意: {relative} を commit していない。出どころのリンクが、貼った再現と違う中身を指す",
              file=sys.stderr)
    evidence = "\n".join(f"![{key}]({url})" for url in shots) or \
        f"{TODO} probes-evidence の手順で組んだ絵の URL。画素に出ない事象なら「不要: 理由」 -->"
    fences = "\n\n".join(f"`{name}`\n\n```swift\n{text.rstrip()}\n```" for name, text in files.items())
    return f"""{BEGIN}
## 事象

{TODO} 何が起きるかを 2〜3 文で。API の識別子は `…` で囲む -->

## 再現

mokume だけで閉じたパッケージで、この 3 つを置いて `swift run` で走る。probes の検査
(`ReprosTests`) も同じファイルを走らせている。

{fences}

走らせた出力 (mokume `v{version}`・終了コード {code}):

```
{output}
```

## 期待と実際

{TODO} 期待 (出典: mokume の ADR・ドキュメント、Processing / p5.js) と、実際 (数と測り方) -->

## 証跡

{evidence}

## 確かめたこと

- 単独の再現: 上のパッケージで出る (`python3 scripts/filing.py repro {ruler} {key}`)
- main: {on_main}
- 反復: {TODO} 何回回して何回出たか (決定論なら「同じ機械で N 回・毎回同じ」) -->
- 陰性対照・境界: {TODO} 破れない隣の条件と、破れ始める境目 -->
- 重複: {TODO} 検索した語と、同じ根の Issue が無かったこと -->

## 当たり

{TODO} タグで固定したソースの行 (`v{version}` の `path:line`)。当たりが無ければ「未確認: 理由」 -->

## 出どころ

物差し [{ruler}]({BLOB_BASE}/{sha}/{ruler}/README.md) の再現
[`{key}`]({BLOB_BASE}/{sha}/{relative})。直ったものが probes に届くと、
`withKnownIssue` が「既知の問題が起きなかった」で赤くなって知らせる。

## 環境

{env_table(environment(ruler))}
{END}
"""


def duplicates(terms: list[str]) -> str:
    """重複の候補。検査が名指ししている文面と、mokume の Issue の検索。"""
    lines = []
    for path in sorted(ROOT.glob("*/Tests/**/*.swift")):
        for match in re.finditer(r'"(mokume#\d+[^"]*)"', path.read_text()):
            if any(t.lower() in match.group(1).lower() for t in terms):
                lines.append(f"  {path.relative_to(ROOT).parts[0]}: {match.group(1)}")
    for term in terms:
        found = capture(["gh", "search", "issues", "--repo", "mokume-metal/mokume", "--limit", "10",
                         "--json", "number,title,state", "--jq", '.[] | "#\\(.number) [\\(.state)] \\(.title)"',
                         term]).splitlines()
        lines.append(f"mokume を「{term}」で検索:")
        lines += [f"  {line}" for line in found] or ["  (無し)"]
    return "\n".join(lines)


# MARK: - 入口

def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="python3 scripts/filing.py", description="mokume への起票を組み、骨格を検める (docs/filing.md)")
    commands = parser.add_subparsers(dest="command", required=True)
    env = commands.add_parser("env", help="環境の表")
    env.add_argument("ruler")
    repro = commands.add_parser("repro", help="再現を単独のパッケージで走らせる (1 = 再現した・0 = 期待どおり・2 = 組めない)")
    repro.add_argument("ruler")
    repro.add_argument("key")
    repro.add_argument("--mokume", help="版の代わりに引く mokume のブランチ (例: main)")
    make = commands.add_parser("draft", help="本文の下書き")
    make.add_argument("ruler")
    make.add_argument("key")
    make.add_argument("--shot", action="append", default=[], help="証跡の URL (GitHub の添付)")
    make.add_argument("--search", action="append", default=[], help="重複の候補を探す語")
    make.add_argument("--skip-main", action="store_true", help="mokume main で走らせない")
    check = commands.add_parser("check", help="骨格を検める (--body が無ければ、名指しした起票を全部)")
    check.add_argument("--body", type=pathlib.Path)
    check.add_argument("--title")
    args = parser.parse_args(argv)

    if args.command == "env":
        print(env_table(environment(args.ruler)))
        return 0
    if args.command == "repro":
        code, output, _ = run_repro(args.ruler, args.key, args.mokume)
        print(output)
        return code
    if args.command == "draft":
        print(draft(args.ruler, args.key, args.shot, args.skip_main))
        if args.search:
            print(f"重複の候補:\n{duplicates(args.search)}", file=sys.stderr)
        return 0
    if args.body is None:
        return check_all()
    problems = check_body(args.body.read_text(), args.title)
    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
