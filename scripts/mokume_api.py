#!/usr/bin/env python3
"""mokume の公開 API 一覧を取り、名前の集合を起こす。

一覧は**リポジトリに置かれず Release 資産として配られる** (mokume ADR-0001 原則 8)。
版を渡せばその版のものが取れるので、2 版ぶん取って集合の差を見ると**増えた口と
消えた口が全部出る**。

**リリースノートからは取れない。** ノートの `## 新機能` は散文で、シンボル名が
バッククォートに入っているとは限らず、「削除」「改名」「追加」の区別も文の中にしか
無い。版上げのたびに知りたいのは「何が書けるようになったか」なので、
一覧の差分のほうが答えに近い。

    import mokume_api
    old = mokume_api.names(mokume_api.text("0.5.0"))
    new = mokume_api.names(mokume_api.text("0.6.0"))
    print(sorted(new - old))
"""

import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / "upstream" / "api"   # gitignore 済み。**取ってきたものはコミットしない**


def _gh(*args: str) -> bytes:
    return subprocess.run(["gh", *args], capture_output=True, check=True).stdout


def text(version: str) -> str:
    """その版の公開 API 一覧。一度取ったものは `upstream/api/` に置いて使い回す。"""
    cached = CACHE / f"mokume-api-v{version}.md"
    if cached.exists():
        return cached.read_text()

    name = f"mokume-api-v{version}.md"
    release = json.loads(_gh("api", f"repos/mokume-metal/mokume/releases/tags/v{version}"))
    asset = next((a for a in release["assets"] if a["name"] == name), None)
    if asset is None:
        raise SystemExit(f"v{version} のリリースに {name} が無い")
    body = _gh("api", f"repos/mokume-metal/mokume/releases/assets/{asset['id']}",
               "-H", "Accept: application/octet-stream")
    CACHE.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(body)
    return body.decode()


def names(text: str) -> set[str]:
    """一覧の Markdown から呼べる名前を起こす。

    **Atlas の台帳が使っている判定と同じ形**にしてある (`Atlas/scripts/ledger.py`)。
    ここを変えると台帳の区分が動くので、両方が同じ集合を見ていることが要る。
    """
    found: set[str] = set(re.findall(r"^## (\w+)", text, re.M))          # 型
    found |= set(re.findall(r"\bfunc\s+([a-zA-Z_]\w*)", text))            # 関数
    found |= set(re.findall(r"\bvar\s+([a-zA-Z_]\w*)", text))             # 値
    found |= set(re.findall(r"\bcase\s+([a-zA-Z_]\w*)", text))            # 列挙の枝
    # アンブレラが名指しで通す三角関数 (Umbrella.swift)。一覧には出ないが呼べる
    found |= {"sin", "cos", "tan", "asin", "acos", "atan", "atan2"}
    return found


# 一覧の宣言行。`## 見出し` がスコープで、型のことも自由関数のこともある
DECL = re.compile(r"^\s*(?:@MainActor\s+)?(?:public\s+)?(?:static\s+)?"
                  r"(?:func|var|let|init|case|subscript)\s+([a-zA-Z_]\w*)")


def signatures(text: str) -> dict[tuple[str, str], set[str]]:
    """(スコープ, 名前) → その名前で書ける署名の集合。

    **名前だけを見ると、いちばん危ないものが見えない。** `isKeyDown` は `v0.5.0` →
    `v0.6.0` で `Int` から `Key` へ変わったが、名前は同じなので `names()` の差では
    「変化なし」になる。書いてあればコンパイルは必ず落ちるのに。
    """
    scope, out = "", {}
    for line in text.splitlines():
        if line.startswith("## "):
            scope = line[3:].strip()
            continue
        if found := DECL.match(line):
            out.setdefault((scope, found.group(1)), set()).add(line.strip())
    return out


def compare(old: str, new: str) -> dict[str, list]:
    """2 つの版の署名を突き合わせ、4 つに分ける。

        消えた         名前ごと無くなった
        通らなくなった  同じ名前で、旧い書き方が消えた
        増えた         新しく書けるようになった
        口が増えた      書き方が増えたが、旧い書き方も通る
    """
    a, b = signatures(old), signatures(new)
    return {
        "gone": sorted(set(a) - set(b)),
        "broke": sorted(k for k in set(a) & set(b) if a[k] - b[k]),
        "added": sorted(set(b) - set(a)),
        "widened": sorted(k for k in set(a) & set(b) if b[k] - a[k] and not (a[k] - b[k])),
        "before": a,
        "after": b,
    }


def headline(text: str) -> str:
    """一覧が冒頭で名乗る規模 (「公開シンボル 1001 個 / 型 92 個。」)。"""
    for line in text.splitlines():
        if "公開シンボル" in line:
            return line.split("。")[0] + "。"
    return ""


def latest() -> dict[str, str]:
    """mokume の最新リリース。"""
    release = json.loads(_gh("api", "repos/mokume-metal/mokume/releases/latest"))
    return {
        "tag": release["tag_name"],
        "version": release["tag_name"].lstrip("v"),
        "published": release["published_at"],
        "body": release["body"],
    }


def breaking(body: str) -> str:
    """リリースノートの `## 破壊的変更` の中身。無ければ空。

    見出しは `破壊的変更 / 新機能 / 修正 / 性能 / ドキュメント` の**閉じた 5 語**で、
    正典は mokume の `scripts/release.py` の `SECTIONS`。だから見出しの有無だけは
    機械で確実に判定できる (中の書式は自由文)。
    """
    out: list[str] = []
    inside = False
    for line in body.splitlines():
        if line.startswith("## "):
            inside = line.strip() == "## 破壊的変更"
            continue
        if inside:
            out.append(line)
    return "\n".join(out).strip()
