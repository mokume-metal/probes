#!/usr/bin/env python3
"""台帳を持つものを走らせて、ビルドが通り版の刻印と揃っているかを見る。

**台帳 (`checks.json`) を持つのは Atlas だけである** (ルート README の「並べ方」)。
Probe・Drift・Reach は台帳の代わりに `swift test` を持つので、名指ししても飛ばす。

    python3 scripts/verify.py                  # 台帳を持つもの全部
    python3 scripts/verify.py Atlas            # 名指し
    python3 scripts/verify.py --check          # 走らせず、台帳と Package.resolved の版だけ見る
    python3 scripts/verify.py --update         # 実測を新しい記録として受け入れる (版上げの後)
    python3 scripts/verify.py --write-readme   # README の生成区間を台帳から書き戻す

**同じフレーム番号からは同じ絵が出る** (mokume ADR-0001 原則 2)。だから期待ハッシュが
食い違ったら、変えたつもりのないところが変わっている。**版を上げた直後は動くのが普通**で、
そのときは何が動いたかを README の散文へ書いてから `--update` で記録を進める。

`--check` は**絵を出さずに**「道具を上げたのに測り直していない」だけを捕まえる。
ビルドも GPU も要らない。
"""

import concurrent.futures
import hashlib
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pieces  # noqa: E402

ROOT = pieces.ROOT


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(path: pathlib.Path, args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=path, capture_output=True, text=True)


def warnings(stderr: str) -> list[str]:
    """mokume が「言われたとおりにしなかった」と申告した行。

    mokume は診断の出口を 1 つに絞り、**必ず `mokume: ` を前置きして標準エラーへ**
    書く。絵は出ているのに中身が違うとき、理由はここにしか出ない
    ([works#19](https://github.com/mokume-metal/works/issues/19))。

    **絵を待ち切れなかったときも黙って進む口がある。** 面の画素を読む・画像を面へ
    送る・字形を焼く経路は 5 秒で諦めて古い写しのまま返す (書き出しそのものは
    諦めずに落ちる)。並行で走らせて混んだときに効くので、警告は必ず拾う。
    """
    return [line for line in stderr.splitlines() if line.startswith("mokume: ")]


def measure(path: pathlib.Path) -> dict:
    """1 本を走らせて実測を集める。**例外は投げず、失敗も結果として返す**。"""
    checks = pieces.load_checks(path)
    out: dict = {"piece": path.name, "rows": [], "error": None}

    for step in checks.get("prepare", []):
        done = subprocess.run(step, cwd=path, shell=True, capture_output=True, text=True)
        if done.returncode:
            out["error"] = f"下ごしらえが失敗した ({step}): {done.stderr.strip()[:200]}"
            return out

    build = ["swift", "build"] + (["-c", "release"] if checks.get("release") else [])
    done = run(path, build)
    if done.returncode:
        out["error"] = f"ビルドが失敗した: {done.stderr.strip()[-400:]}"
        return out

    # **書き出しを 1 枚も宣言しないものがある。** Atlas は例ごとに独立したスケッチを
    # 持つ置き場で、絵の再現はもう測らない。それでも版の刻印と「ビルドが
    # 通るか」は他と同じ形で見たいので、`renders` を空にして通す
    for check in checks["renders"]:
        command = pieces.command(path, check, checks)
        done = run(path, command)
        wrote = path / check["out"]
        said = warnings(done.stderr)
        if done.returncode or not wrote.exists():
            out["rows"].append({"what": check["args"], "want": check["sha256"],
                                "got": None, "said": said,
                                "note": done.stderr.strip()[-200:]})
            continue
        out["rows"].append({"what": check["args"], "want": check["sha256"],
                            "got": digest(wrote), "said": said})
    return out


def unsettled(result: dict) -> bool:
    """この物差しに、測り直す価値のある疑いがあるか。"""
    if result["error"]:
        return True
    for row in result["rows"]:
        if row.get("said"):
            return True
        if row["got"] != row["want"]:
            return True
    return False


def stale(path: pathlib.Path) -> str | None:
    """台帳の版と、いま解決している版の食い違い。"""
    checks = pieces.load_checks(path)
    pin = pieces.pinned(path)
    if checks["mokume"] != pin["version"] or checks["revision"] != pin["revision"]:
        return f"台帳は `v{checks['mokume']}` / いまは `v{pin['version']}`"
    if pieces.declared(path) != pin["version"]:
        return f"`Package.swift` は `{pieces.declared(path)}` / 解決は `{pin['version']}`"
    return None


def render_pins(path: pathlib.Path, checks: dict) -> str:
    """README の版の表。"""
    # **works の番号は works にいた頃の記録。** probes へ移ってからの版は、この物差しの
    # コミットそのものが持つ
    if "works" in checks:
        place = "works"
        commit = (f"[#{checks['works']}](https://github.com/mokume-metal/works/pull/{checks['works']})"
                  " の merge コミット (`Package.resolved` が同じツリーにある)")
    else:
        place = "probes"
        commit = "この物差しのコミット (`Package.resolved` が同じツリーにある)"
    rows = ["| | |", "| --- | --- |", f"| {place} | {commit} |",
            f"| mokume | `v{checks['mokume']}` / `{checks['revision']}`"
            " (`Package.resolved` が固定している) |"]
    if "origin" in checks:
        import json
        sources = json.loads((path / "ledger" / "sources.json").read_text())
        sha = sources["examples"]["sha"]
        rows.append(f"| 原典 | `{checks['origin']}` @ `{sha}`"
                    " ([`ledger/sources.json`](ledger/sources.json) が刻む) |")
    return "\n".join(rows)


def render_renders(path: pathlib.Path, checks: dict) -> str:
    """README の書き出しブロック。

    **書き出しを 1 枚も宣言しないものでは、ブロックごと空にする。** 空の ```bash を
    置くと「ここに手順があるはずなのに書かれていない」と読めてしまう。
    """
    if not checks["renders"]:
        return ""
    lines = ["```bash"]
    for i, check in enumerate(checks["renders"]):
        if i:
            lines.append("")
        lines.append(f"{pieces.shown(path, check, checks)} && shasum -a 256 {check['out']}")
        lines.append(f"# {check['sha256']}")
    lines.append("```")
    return "\n".join(lines)


def write_readme(path: pathlib.Path) -> list[str]:
    checks = pieces.load_checks(path)
    readme = path / "README.md"
    touched = []
    if pieces.write_section(readme, pieces.OPEN_PINS, render_pins(path, checks)):
        touched.append("版の表")
    if pieces.write_section(readme, pieces.OPEN_RENDERS, render_renders(path, checks)):
        touched.append("書き出し")
    return touched


def main(argv: list[str]) -> int:
    flags = {a for a in argv if a.startswith("--")}
    named = [a for a in argv if not a.startswith("--")]
    jobs = 1
    for flag in list(flags):
        if flag.startswith("--jobs="):
            jobs = int(flag.split("=")[1])
            flags.discard(flag)
    targets = [pieces.piece(n) for n in named] if named else pieces.pieces()

    if unknown := flags - {"--check", "--update", "--write-readme"}:
        raise SystemExit(f"知らない指定: {', '.join(sorted(unknown))}\n{__doc__}")

    # **台帳を持たないものは歩かない。** Probe と Drift は `swift test` で見るので、
    # 台帳で版の刻印を測るのは Atlas だけである (ルート README)
    if skipped := [p.name for p in targets if not pieces.has_checks(p)]:
        if named:
            print(f"台帳を持たないので飛ばす: {', '.join(skipped)}")
        targets = [p for p in targets if pieces.has_checks(p)]
    if not targets:
        print("台帳を持つものが無い。")
        return 0

    if "--write-readme" in flags:
        dirty = False
        for path in targets:
            touched = write_readme(path)
            print(f"{path.name}: {'書き戻した (' + '・'.join(touched) + ')' if touched else '変わらない'}")
            dirty |= bool(touched)
        return 0

    if "--check" in flags:
        bad = 0
        for path in targets:
            if note := stale(path):
                print(f"{path.name}: **測り直していない** — {note}")
                bad += 1
        print("台帳の版はどれも解決している版と揃っている。" if not bad else
              f"\n{bad} 本が古い。`verify.py --update` の前に、何が動いたかを README へ書く。")
        return 1 if bad else 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(measure, targets))

    # **並行で動いた絵は、1 回では確定させない。** 混んだときに黙って古い写しを返す
    # 経路があるので、疑わしいものだけ他を止めて測り直す (#22 が手でやった切り分け)
    retried: set[str] = set()
    if jobs > 1:
        suspect = [i for i, r in enumerate(results) if unsettled(r)]
        for i in suspect:
            fresh = measure(targets[i])
            retried.add(targets[i].name)
            if unsettled(fresh) and fresh["rows"] == results[i]["rows"]:
                continue          # 2 度同じなら版差か書き直しである
            results[i] = fresh    # 揺れていた。単独の結果を採る

    print("| 物差し | 書き出し | 記録 | 実測 | |")
    print("| --- | --- | --- | --- | --- |")
    moved = failed = 0
    for result in results:
        if result["error"]:
            print(f"| {result['piece']} | — | — | — | **走らなかった** |")
            failed += 1
            continue
        for row in result["rows"]:
            if "same" in row:   # 台帳と突き合わせた (Atlas)
                mark = "一致" if row["same"] else f"**{len(row['moved'])} 枚動いた**"
                if not row["same"]:
                    moved += 1
                print(f"| {result['piece']} | `{row['what']}` | {row['want']} | {row['got']} | {mark} |")
                continue
            if row["got"] is None:
                print(f"| {result['piece']} | `{row['what']}` | `{row['want'][:8]}…` | — | **書き出せなかった** |")
                failed += 1
            elif row["got"] == row["want"]:
                print(f"| {result['piece']} | `{row['what']}` | `{row['want'][:8]}…` | `{row['got'][:8]}…` | 一致 |")
            else:
                print(f"| {result['piece']} | `{row['what']}` | `{row['want'][:8]}…` | `{row['got'][:8]}…` | **動いた** |")
                moved += 1

    if retried:
        print(f"\n> 並行で走らせて疑いの出た {'・'.join(sorted(retried))} は、"
              "他を止めて 1 本ずつ測り直した結果を載せている。")

    said = {r["piece"]: sorted({w for row in r["rows"] for w in row.get("said", [])})
            for r in results}
    if any(said.values()):
        print("\n### mokume が言ったこと\n")
        print("**「言われたとおりにしなかった」という申告である。**"
              " 絵が食い違う理由は、たいていここに出ている。\n")
        for piece, lines in said.items():
            for line in lines:
                print(f"- **{piece}** — `{line}`")

    for result in results:
        if result["error"]:
            print(f"\n**{result['piece']} が走らなかった** — {result['error']}")
        for row in result.get("rows", []):
            for kind, label in (("moved", "動いた"), ("missing", "消えた"), ("added", "増えた")):
                if row.get(kind):
                    print(f"\n**{result['piece']} で{label} {len(row[kind])} 枚**: "
                          + ", ".join(f"`{n}`" for n in row[kind][:12])
                          + (" …" if len(row[kind]) > 12 else ""))

    if "--update" in flags:
        for result, path in zip(results, targets):
            if result["error"]:
                continue
            checks = pieces.load_checks(path)
            for check, row in zip(checks["renders"], result["rows"]):
                if row["got"]:
                    check["sha256"] = row["got"]
            pin = pieces.pinned(path)
            checks["mokume"], checks["revision"] = pin["version"], pin["revision"]
            pieces.save_checks(path, checks)
        print("\n台帳を実測で更新した。`--write-readme` で README へ送る。")
        return 0

    return 1 if (moved or failed) else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
