#!/usr/bin/env python3
"""いま何を引いていて、mokume はどこまで行っているかを 1 枚で出す。

    python3 scripts/status.py           # 一覧
    python3 scripts/status.py --check   # 追随が要るなら終了コード 1 (CI が見る)

**版は 2 か所か 3 か所にある。** `Package.swift` の `from:` は記録 (留め金ではない)、
`Package.resolved` が実際に固定している版。**台帳 (`checks.json`) を持つ物差しでは**
さらにその期待ハッシュを測ったときの版が載る。揃っていないと、どれかの作業が途中で
止まっている。台帳を持たないもの (Probe・Drift) では「測った版」は `—` になる。
"""

import subprocess
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import mokume_api  # noqa: E402
import pieces  # noqa: E402


def tool() -> str:
    """手元の CLI が名乗る版。`v0.6.0` から名乗れるようになった (mokume#634)。"""
    try:
        done = subprocess.run(["mokume", "version"], capture_output=True, text=True, timeout=10)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "入っていない"
    return done.stdout.strip() if done.returncode == 0 else "版を名乗れない (v0.6.0 より前)"


def main(argv: list[str]) -> int:
    check = "--check" in argv
    latest = mokume_api.latest()
    rows = []
    for path in pieces.pieces():
        pin = pieces.pinned(path)
        # 台帳を持つのは Atlas だけなので、測った版が無いものがある
        checks = pieces.load_checks(path) if pieces.has_checks(path) else None
        rows.append({
            "piece": path.name,
            "declared": pieces.declared(path),
            "resolved": pin["version"],
            "measured": checks["mokume"] if checks else None,
            "behind": pin["version"] != latest["version"],
        })

    behind = [r for r in rows if r["behind"]]
    ragged = [r for r in rows
              if r["declared"] != r["resolved"]
              or (r["measured"] is not None and r["measured"] != r["resolved"])]

    if check:
        if behind:
            print(f"mokume {latest['tag']} ({latest['published'][:10]}) が出ている。"
                  f"追随していないのは {', '.join(r['piece'] for r in behind)}。")
        return 1 if behind else 0

    print(f"## mokume は `{latest['tag']}` ({latest['published'][:10]} 公開)\n")
    print(f"手元の道具: {tool()}\n")
    print("| 物差し | `Package.swift` | 解決している版 | 測った版 | |")
    print("| --- | --- | --- | --- | --- |")
    for r in rows:
        mark = "**追随していない**" if r["behind"] else ("**揃っていない**" if r in ragged else "追随済み")
        measured = f"`{r['measured']}`" if r["measured"] else "—"
        print(f"| {r['piece']} | `{r['declared']}` | `{r['resolved']}` | {measured} | {mark} |")

    if behind:
        print(f"\n**{len(behind)} 本が `v{latest['version']}` を引いていない。**"
              " 何が変わったかは `python3 scripts/api-diff.py` で見る。")
        if breaking := mokume_api.breaking(latest["body"]):
            print(f"\n### `{latest['tag']}` の破壊的変更\n\n{breaking}")
    elif ragged:
        print("\n**版の記録が揃っていないものがある。** `verify.py --check` が理由を出す。")
    else:
        print("\n全部が最新の mokume を引いていて、記録も揃っている。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
