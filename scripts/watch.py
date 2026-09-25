#!/usr/bin/env python3
"""mokume が新しい版を出していないか見に行き、追随の Issue を立てる。

    python3 scripts/watch.py --dry-run   # 立てずに本文を出す
    python3 scripts/watch.py             # 立てる (無ければ) / 直す (あれば)

**あちらから通知は来ない。** mokume の
[ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)
が「依存は一方向」と決めているので、probes が見に行く以外に道が無い
(`mokume-metal/homebrew-tap` が repository_dispatch をやめて日次のポーリングにしたのと
同じ理由 — 伝える形にすると mokume 側へこのリポジトリを書ける鍵を常設することになる)。

**版が追随より速いことがある。** v0.1.0 から v0.6.0 まで 10 日で 6 版出ており、追随の
途中で次が出るのは想定内である。だから Issue は**版ごとではなく追随の 1 巡ごとに 1 本**で、
open なものがあれば立て直さずに本文を書き直す。判定に使うのはタイトルの版文字列ではなく
ラベルで、機械が読み書きするのは本文の頭に置いた 1 行のコメントだけ。散文とタイトルは人のもの。

**差があること自体は失敗ではない。** 「壊れていることは情報であって故障ではない」
(ルート README) ので、遅れを見つけてもこのスクリプトは 0 で戻る。**0 でなくなるのは
見に行けなかったとき**だけ — つまり終了コードは「検出が動いたか」だけを表す。
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import mokume_api  # noqa: E402
import pieces  # noqa: E402
import upstream  # noqa: E402

LABEL = "mokume: behind"
MARK = "<!-- mokume-watch: "
REPO = "mokume-metal/probes"


def gh(*args: str) -> str:
    done = subprocess.run(["gh", *args], capture_output=True, text=True)
    if done.returncode:
        raise SystemExit(f"gh {' '.join(args)} が失敗した: {done.stderr.strip()[:300]}")
    return done.stdout


def state() -> dict:
    """いまの追随の状態。**ここが見に行く唯一の場所**。"""
    latest = mokume_api.latest()
    drawn = {p.name: pieces.pinned(p)["version"] for p in pieces.pieces()}
    return {
        "latest": latest["version"],
        "tag": latest["tag"],
        "published": latest["published"],
        "body": latest["body"],
        "works": drawn,
        "behind": sorted(n for n, v in drawn.items() if v != latest["version"]),
    }


def closed_since(oldest: str) -> list[dict]:
    """probes が戻した Issue のうち、閉じているもの。

    **「閉じた」は「その版に入った」ではない。** 閉じた日がリリースより後なら直しは
    次の版に乗るので、日付も添えて人に判じてもらう。
    """
    where = upstream.mentioned()
    import concurrent.futures
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        found = list(pool.map(upstream.fetch, sorted(where)))
    return sorted((r for r in found
                   if r.get("state") == "closed" and not r.get("pr") and r.get("closed")),
                  key=lambda r: r["closed"], reverse=True)


def body(now: dict) -> str:
    """Issue の本文。**機械が読み書きするのは頭の 1 行だけ**。"""
    machine = json.dumps({"latest": now["latest"], "works": now["works"]},
                         ensure_ascii=False, sort_keys=True)
    out = [f"{MARK}{machine} -->", ""]
    out.append(f"mokume が [`{now['tag']}`](https://github.com/mokume-metal/mokume/releases/tag/{now['tag']})"
               f" を出した ({now['published'][:10]})。**{len(now['behind'])} 本**が追随していない。")
    out.append("")
    out.append("| 物差し | 引いている版 | |")
    out.append("| --- | --- | --- |")
    for name, version in sorted(now["works"].items()):
        mark = "**追随していない**" if name in now["behind"] else "追随済み"
        out.append(f"| [{name}]({name}/) | `v{version}` | {mark} |")

    if breaking := mokume_api.breaking(now["body"]):
        out += ["", "## リリースノートが挙げた破壊的変更", "", breaking]

    oldest = sorted(set(now["works"].values()),
                    key=lambda v: [int(n) for n in v.split(".")])[0]
    if oldest != now["latest"]:
        try:
            diff = mokume_api.compare(mokume_api.text(oldest), mokume_api.text(now["latest"]))
        except SystemExit:
            diff = None
        if diff:
            out += ["", f"## 公開 API — `v{oldest}` → `v{now['latest']}`", "",
                    f"消えた **{len(diff['gone'])}** / 通らなくなった **{len(diff['broke'])}**"
                    f" / 増えた {len(diff['added'])} / 書き方が増えた {len(diff['widened'])}", ""]
            if diff["gone"] or diff["broke"]:
                out.append("**直さないと通らないもの:**")
                out.append("")
                for scope, name in diff["gone"]:
                    out.append(f"- `{scope}.{name}` が消えた")
                for scope, name in diff["broke"]:
                    for line in sorted(diff["before"][(scope, name)] - diff["after"][(scope, name)]):
                        out.append(f"- `{scope}.{name}` — `{line}` が通らなくなった")
                out.append("")
            out.append("**ノートに出ない変更がある。** 名前が同じまま型だけ変わったものは"
                       " `## 破壊的変更` にも `## 新機能` にも書かれないことがあるので、"
                       "`python3 scripts/api-diff.py` を読んでから始める。")

    if closed := closed_since(oldest):
        out += ["", "## probes が戻したもののうち、閉じているもの", "",
                "**閉じた日がリリースより後なら、直しが乗るのは次の版である。**", "",
                "| | 型 | 閉じた日 |", "| --- | --- | --- |"]
        for row in closed[:12]:
            out.append(f"| [#{row['number']}](https://github.com/mokume-metal/mokume/issues/{row['number']})"
                       f" {row['title'][:48]} | {row['type'] or '—'} | {row['closed'][:10]} |")

    out += ["", "## 進め方", "",
            "手順は `.claude/skills/probes-bump/`。**版だけ上げて基準線を取ってから**"
            "書き直す (そうしないと絵が動いた理由が版差か書き直しか分からない)。", "",
            "```bash",
            "python3 scripts/status.py                 # いまの食い違い",
            f"python3 scripts/api-diff.py {oldest} {now['latest']}   # 何が変わったか",
            f"python3 scripts/bump.py {now['latest']}              # 版を上げる (中身は変えない)",
            "python3 scripts/verify.py --jobs=4        # 台帳を持つ物差しを測り直す",
            "(cd Probe && swift test); (cd Drift && swift test); (cd Routine && swift test); (cd Soak && swift test)   # 赤くなったものは直った約束",
            "(cd Reach && swift test)                  # 届く口の一覧 (増えた口で穴が埋まっていないかも見る)",
            "```", ""]
    for name in sorted(now["works"]):
        mark = "x" if name not in now["behind"] else " "
        out.append(f"- [{mark}] **{name}**")
    out += ["", "---",
            "<sub>🤖 Assisted by [Claude Code](https://claude.com/claude-code)</sub>"]
    return "\n".join(out)


def open_issue() -> dict | None:
    found = json.loads(gh("issue", "list", "--repo", REPO, "--label", LABEL,
                          "--state", "open", "--json", "number,body,title"))
    return found[0] if found else None


def ensure_label() -> None:
    have = json.loads(gh("label", "list", "--repo", REPO, "--json", "name"))
    if not any(row["name"] == LABEL for row in have):
        gh("label", "create", LABEL, "--repo", REPO, "--color", "d4c5f9",
           "--description", "mokume の新しい版に追随していない")


def main(argv: list[str]) -> int:
    now = state()
    if "--dry-run" in argv:
        print(body(now) if now["behind"] else
              f"全 {len(now['works'])} 本が `{now['tag']}` を引いている。立てる Issue は無い。")
        return 0

    if not now["behind"]:
        print(f"全部が {now['tag']} を引いている。何もしない。")
        return 0

    ensure_label()
    fresh = body(now)
    if standing := open_issue():
        was = standing["body"].split(" -->")[0].replace(MARK, "") if MARK in standing["body"] else ""
        if was == json.dumps({"latest": now["latest"], "works": now["works"]},
                             ensure_ascii=False, sort_keys=True):
            print(f"#{standing['number']} が同じ状態で開いている。何もしない。")
            return 0
        path = pathlib.Path("/tmp/mokume-watch-body.md")
        path.write_text(fresh)
        gh("issue", "edit", str(standing["number"]), "--repo", REPO, "--body-file", str(path))
        print(f"#{standing['number']} の本文を書き直した。")
        return 0

    path = pathlib.Path("/tmp/mokume-watch-body.md")
    path.write_text(fresh)
    url = gh("issue", "create", "--repo", REPO, "--label", LABEL,
             "--title", f"mokume {now['tag']} へ追随する", "--body-file", str(path)).strip()
    print(f"立てた: {url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
