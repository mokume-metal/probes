#!/usr/bin/env python3
"""物差しの並びと、その版・台帳・README の生成区間。

**1 本 = 1 フォルダ = 1 SwiftPM パッケージ**なので (ルート README)、直下で
`Package.swift` を持つディレクトリがそのまま一覧になる。増えても
この関数は何も知らずに拾う。

    from pieces import pieces, pinned, load_checks

**台帳 (`checks.json`) を持つのは Atlas だけである。** Probe と Drift は台帳の代わりに
`swift test` を持ち、約束の破れを `withKnownIssue` で押さえる (ルート README)。
台帳を歩く道具は `has_checks()` で先に絞る。

**持っているものでは、版は 2 か所にある。** `Package.resolved` が「いま解決している版」、
`checks.json` が「その記録を取ったときの版」。食い違っていたら**道具を上げたのに測り直して
いない**。

README の「検証する」節は 2 つの印で囲った区間だけが生成物で、**散文は手書きのまま
残す**。囲いを 2 つに割ってあるのは、版の表と書き出しの間に手書きの注意書きが挟まる
ためで、1 つで囲うとそれを飲み込む。
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# README の生成区間。開きは種類ごと、閉じは共通
OPEN_PINS = "<!-- verify:pins -->"
OPEN_RENDERS = "<!-- verify:renders -->"
CLOSE = "<!-- verify:end -->"


def pieces() -> list[pathlib.Path]:
    """物差しのフォルダ。並びは名前順で固定する (出力を読む側が予測できるように)。"""
    return sorted(p.parent for p in ROOT.glob("*/Package.swift"))


def piece(name: str) -> pathlib.Path:
    """名前から物差しのフォルダ。大文字小文字は問わない。"""
    for path in pieces():
        if path.name.lower() == name.lower():
            return path
    raise SystemExit(f"そんな物差しは無い: {name} (あるのは {', '.join(p.name for p in pieces())})")


def pinned(path: pathlib.Path) -> dict[str, str]:
    """`Package.resolved` がいま固定している mokume の版と revision。"""
    resolved = json.loads((path / "Package.resolved").read_text())
    pin = next(p for p in resolved["pins"] if p["identity"] == "mokume")
    return {"version": pin["state"]["version"], "revision": pin["state"]["revision"]}


def declared(path: pathlib.Path) -> str:
    """`Package.swift` が `from:` で名乗っている版。

    **留め金ではなく記録である** — SwiftPM の `from:` は 0.x を特別扱いしないので、
    古いまま置いても `swift package update` は新しい版を拾う (works#22 で実測)。
    実際に固定しているのは `Package.resolved` のほう。
    """
    for line in (path / "Package.swift").read_text().splitlines():
        if "from:" in line:
            return line.split('from:')[1].strip().strip('")],').strip('"')
    raise SystemExit(f"{path.name}/Package.swift に from: が無い")


def checks_path(path: pathlib.Path) -> pathlib.Path:
    return path / "checks.json"


def has_checks(path: pathlib.Path) -> bool:
    """再現の台帳を持っているか。**持たないものを歩く前に、ここで絞る。**"""
    return checks_path(path).exists()


def load_checks(path: pathlib.Path) -> dict:
    return json.loads(checks_path(path).read_text())


def save_checks(path: pathlib.Path, data: dict) -> None:
    checks_path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def command(path: pathlib.Path, check: dict, checks: dict) -> list[str]:
    """1 つの書き出しを走らせるコマンド。"""
    release = ["-c", "release"] if checks.get("release") else []
    return ["swift", "run", *release, path.name, *check["args"].split()]


def shown(path: pathlib.Path, check: dict, checks: dict) -> str:
    """README に載せる形。`swift run` から先だけを見せる。"""
    return " ".join(command(path, check, checks))


def write_section(readme: pathlib.Path, opener: str, body: str) -> bool:
    """印で囲った区間を差し替える。**中身が同じなら書かない** (mtime を動かさない)。

    印が無ければ**足さない** — どこへ置くかは記録の書き手が決めることなので、
    黙って挿し込むと散文の流れを壊す。
    """
    text = readme.read_text()
    if opener not in text:
        raise SystemExit(f"{readme.relative_to(ROOT)} に {opener} が無い")
    head, rest = text.split(opener, 1)
    if CLOSE not in rest:
        raise SystemExit(f"{readme.relative_to(ROOT)} の {opener} に {CLOSE} が無い")
    _, tail = rest.split(CLOSE, 1)
    fresh = f"{head}{opener}\n{body.rstrip()}\n{CLOSE}{tail}"
    if fresh == text:
        return False
    readme.write_text(fresh)
    return True
