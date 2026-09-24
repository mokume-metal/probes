#!/usr/bin/env python3
"""probes の物差しが mokume へ戻したものが、いまどうなっているかを引く。

    python3 scripts/upstream.py            # 全件
    python3 scripts/upstream.py --stale     # 書き戻していないものだけ

**リリースノートからは閉じた Issue が取れない** (v0.6.0 の本文に載っていた Issue は
1 本だけ、v0.5.0 は 0 本)。戻したものの控えを持っているのは各物差しの README なので、
そこから番号を集めて開閉を引く。

**「閉じた」は「その版に入った」ではない。** 閉じた日がリリースより後なら、直しは
次の版に乗る (v0.6.0 の直前に閉じた mokume#917 が実際そうだった)。閉じた日も出すので、
畳む前にリリースの日付と比べること。

**リンクの綴りが `issues/` でも中身が PR のことがある** (GitHub がリダイレクトするので
書いた側は気付かない)。PR は `state` の綴りも違うので、ここで分けて出す。
"""

import concurrent.futures
import json
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pieces  # noqa: E402

ROOT = pieces.ROOT
LINK = re.compile(r"mokume-metal/mokume/issues/(\d+)")
HEADER = re.compile(r"^\| 踏んだもの \|")


def readmes() -> list[pathlib.Path]:
    return [ROOT / "README.md"] + [p / "README.md" for p in pieces.pieces()]


def mentioned() -> dict[int, set[str]]:
    """番号 → それを書いている README の名前。"""
    out: dict[int, set[str]] = {}
    for readme in readmes():
        where = readme.parent.name if readme.parent != ROOT else "ルート"
        for number in LINK.findall(readme.read_text()):
            out.setdefault(int(number), set()).add(where)
    return out


def recorded() -> dict[int, dict]:
    """「mokume へ戻したもの」の表が、その番号に何と書いているか。

    表の形は `| 踏んだもの | <リンク> |` の 2 列か、状態を持つ 3 列。**2 列のままの
    表は、閉じた Issue の行き先が書かれていない**ことになる。
    """
    out: dict[int, dict] = {}
    for readme in readmes():
        where = readme.parent.name if readme.parent != ROOT else "ルート"
        rows: list[str] = []
        columns = 0
        for line in readme.read_text().splitlines():
            if HEADER.match(line):
                columns = len(line.split("|")) - 2
                rows = []
                continue
            if columns and line.startswith("|") and not line.startswith("| ---"):
                rows.append(line)
            elif columns and not line.startswith("|"):
                columns = 0
            for row in rows[-1:]:
                for number in LINK.findall(row):
                    cells = [c.strip() for c in row.split("|")[1:-1]]
                    out[int(number)] = {"piece": where, "columns": columns,
                                        "state": cells[2] if len(cells) > 2 else ""}
    return out


def fetch(number: int) -> dict:
    done = subprocess.run(
        ["gh", "api", f"repos/mokume-metal/mokume/issues/{number}"],
        capture_output=True, text=True)
    if done.returncode:
        return {"number": number, "error": done.stderr.strip()[:120]}
    raw = json.loads(done.stdout)
    return {"number": number, "pr": raw.get("pull_request") is not None,
            "state": raw["state"], "closed": raw.get("closed_at"),
            "type": (raw.get("type") or {}).get("name"), "title": raw["title"]}


def main(argv: list[str]) -> int:
    only_stale = "--stale" in argv
    where, table = mentioned(), recorded()
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        found = sorted(pool.map(fetch, sorted(where)), key=lambda r: r["number"])

    stale = []
    for row in found:
        note = table.get(row["number"])
        row["written"] = bool(note and note["state"])
        closed = row.get("state") == "closed" and not row.get("pr")
        if closed and note and not note["state"]:
            stale.append(row)

    if not only_stale:
        print(f"## probes が mokume へ戻したもの ({len(found)} 件)\n")
        print("| | 型 | いま | 閉じた日 | 書いている物差し | 表の状態 |")
        print("| --- | --- | --- | --- | --- | --- |")
        for row in found:
            if "error" in row:
                print(f"| #{row['number']} | | **引けない** | | {'・'.join(sorted(where[row['number']]))} | |")
                continue
            kind = "PR" if row["pr"] else (row["type"] or "—")
            state = {"open": "open", "closed": "**closed**"}.get(row["state"], row["state"])
            note = table.get(row["number"])
            written = note["state"] if note and note["state"] else ("—" if note else "(表に無い)")
            print(f"| [#{row['number']}](https://github.com/mokume-metal/mokume/issues/{row['number']})"
                  f" | {kind} | {state} | {(row.get('closed') or '')[:10]}"
                  f" | {'・'.join(sorted(where[row['number']]))} | {written} |")

    if stale:
        print(f"\n### 閉じたのに、probes の表が行き先を書いていない ({len(stale)} 件)\n")
        for row in stale:
            note = table[row["number"]]
            print(f"- **{note['piece']}** — [#{row['number']}](https://github.com/mokume-metal/mokume/issues/{row['number']})"
                  f" ({row['title']}) が {row['closed'][:10]} に閉じている。"
                  f"表は {note['columns']} 列で、状態を書く列が{'無い' if note['columns'] < 3 else '空'}")
        print("\n**どの版で塞がったかを確かめてから書く。** 閉じた日がリリースより後なら、"
              "直しが乗るのは次の版である。")
    elif only_stale:
        print("戻したものの行き先は、どれも書き戻してある。")
    return 1 if stale else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
