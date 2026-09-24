#!/usr/bin/env python3
"""2 つの版の公開 API を突き合わせ、何が書けるようになり、何が通らなくなったかを出す。

    python3 scripts/api-diff.py                # 物差しが引いている最も古い版 → 最新版
    python3 scripts/api-diff.py 0.5.0 0.6.0    # 版を名指しする

**名前だけを見ると、いちばん危ないものが見えない。** `isKeyDown` は `v0.5.0` →
`v0.6.0` で `Int` から `Key` へ変わったが、名前は同じなので名前の集合では「変化なし」に
なる。書いてあればコンパイルは必ず落ちるのに。だからここは**署名 1 行を単位**にして、
3 つに分ける:

    消えた       名前ごと無くなった (`LinearRGBA.opaque`)
    通らなくなった 同じ名前で、旧い書き方が消えた (`isKeyDown(_ code: Int)`)
    増えた       新しく書けるようになった

**リリースノートも取りこぼす。** `v0.6.0` の `## 破壊的変更` は 2 件しか挙げていないが、
`## 新機能` の中に太字で 2 件が埋まっており、さらに 4 件はノートに 1 度も出てこない。

見ているのは署名の字面だけで、**振る舞いの変化は写らない**。Atlas の台帳が「予測で
あって検証ではない」と書いているのと同じ限界がここにもある。
"""

import subprocess
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import mokume_api  # noqa: E402
import pieces  # noqa: E402

def touched(names: set[str]) -> dict[str, list[str]]:
    """その名前に probes のどこが触れているか。

    **Swift だけ見ると足りない。** Atlas の台帳 (`vocabulary.jsonl` / `summary.md`) は
    mokume の口を名指しで持っているし、README は語彙の対応表を持っている。
    works#21 が「該当ゼロ件」と結論したとき、見ていたのは Swift だけだった。
    """
    out: dict[str, list[str]] = {}
    for name in sorted(names):
        done = subprocess.run(
            ["grep", "-rlw", name, ".",
             "--include=*.swift", "--include=*.md", "--include=*.jsonl",
             "--exclude-dir=.build", "--exclude-dir=upstream", "--exclude-dir=.git"],
            cwd=pieces.ROOT, capture_output=True, text=True)
        # **行で割る。** 空白を含むパスがある (`Topics/Image Processing/…`)
        hits = [line[2:] if line.startswith("./") else line
                for line in done.stdout.splitlines() if line.strip()]
        if hits:
            out[name] = sorted(hits)
    return out


def describe(hits: list[str]) -> str:
    """当たりの伝え方。**ありふれた名前は絞れない**ので、そう言う。"""
    if not hits:
        return "probes は触れていない"
    if len(hits) > 8:
        return (f"名前がありふれていて **{len(hits)} ファイル**に当たる — 別の口を指している"
                "見込みが高い。絞るには当たりを読む")
    return "**probes が触れている**: " + "・".join(f"`{h}`" for h in hits)


def main(argv: list[str]) -> int:
    if len(argv) == 2:
        old, new = (v.lstrip("v") for v in argv)
    elif not argv:
        drawn = {pieces.pinned(p)["version"] for p in pieces.pieces()}
        old = sorted(drawn, key=lambda v: [int(n) for n in v.split(".")])[0]
        new = mokume_api.latest()["version"]
        if old == new:
            print(f"物差しも mokume も v{new}。差分は無い。", file=sys.stderr)
            return 0
    else:
        raise SystemExit(__doc__)

    before, after = mokume_api.text(old), mokume_api.text(new)
    diff = mokume_api.compare(before, after)
    a, b = diff["before"], diff["after"]
    gone, broke, added, widened = diff["gone"], diff["broke"], diff["added"], diff["widened"]

    print(f"## mokume `v{old}` → `v{new}` の公開 API\n")
    print(f"- `v{old}` — {mokume_api.headline(before)}")
    print(f"- `v{new}` — {mokume_api.headline(after)}\n")
    print("| | 数 | |")
    print("| --- | ---: | --- |")
    print(f"| **消えた** | {len(gone)} | 名前ごと無くなった |")
    print(f"| **通らなくなった** | {len(broke)} | 同じ名前だが旧い書き方が消えた |")
    print(f"| 増えた | {len(added)} | 新しく書ける |")
    print(f"| 口が増えた | {len(widened)} | 旧い書き方はそのまま通る |")

    risky = {name for _, name in gone} | {name for _, name in broke}
    where = touched(risky)

    if gone or broke:
        print(f"\n### 直さないと通らないもの ({len(gone) + len(broke)})\n")
        for scope, name in gone:
            hits = where.get(name, [])
            print(f"- **`{scope}.{name}` が消えた** — `{sorted(a[(scope, name)])[0]}`")
            print("  - " + describe(hits))
        for scope, name in broke:
            hits = where.get(name, [])
            for old_line in sorted(a[(scope, name)] - b[(scope, name)]):
                print(f"- **`{scope}.{name}` の書き方が変わった**")
                print(f"  - 通らない: `{old_line}`")
                for fresh in sorted(b[(scope, name)]):
                    print(f"  - 通る: `{fresh}`")
            print("  - " + describe(hits))
        print("\n**当たったものは実際に読む。** 名前が同じでも別の型の口かもしれない。")

    if added:
        print(f"\n### 増えた ({len(added)})\n")
        by_scope: dict[str, list[str]] = {}
        for scope, name in added:
            by_scope.setdefault(scope or "(自由関数)", []).append(name)
        for scope in sorted(by_scope):
            print(f"- `{scope}` — " + ", ".join(f"`{n}`" for n in sorted(by_scope[scope])))

    if widened:
        print(f"\n### 書き方が増えた ({len(widened)}) — 旧い書き方も通る\n")
        print(", ".join(f"`{name}`" for _, name in widened[:40])
              + (" …" if len(widened) > 40 else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
