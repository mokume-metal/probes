#!/usr/bin/env python3
"""Tumble のドライバ。種の範囲を子プロセスで回し、破れた列を縮める。

    python3 Tumble/scripts/tumble.py run --seeds 0..<2000          # 回して破れを集める
    python3 Tumble/scripts/tumble.py shrink 417 --break sentinel   # 種 417 の列を縮める
    python3 Tumble/scripts/tumble.py shrink Tumble/Findings/x.json --break crash
    python3 Tumble/scripts/tumble.py run --seeds 0..<300 --soak       # 列を繰り返して漏れを測る

**落ちる・止まるは、回している子プロセスの終わり方で見る。** 1 本の子プロセスで種を束で
回し、落ちたら (signal)・止まったら (出力が 20 秒進まない) 、最後に名乗った種をその破れとして記録し、
次の種から新しい子プロセスで続ける。判定の残り 4 つ (投げる・毎回同じ絵・番兵・数でない画素)
は子プロセスが 1 種 1 行の JSON で返す (Sources/Tumble/Examine.swift)。`--soak` を付けると、
判定の代わりに列のフレームを 240 枚繰り返し、footprint と GPU の確保量の増え方を返す
(`leak` / `gpuLeak`)。

**縮小器は delta debugging で、同じ種類の破れが出続ける最小の列を探す。** フレームを
落とす → 口を落とす (塊から 1 つずつ) → 端の値をふつうの値 (`tame`) へ戻す、の順に、
変わらなくなるまで繰り返す。1 回の試しは子プロセス 1 本 (0.2 秒前後) なので、縮めるのに
数十秒かかる。

**probes のものである。** works には写さない (CLAUDE.md の scripts/ の注意は、ルートの
`scripts/` に対してのもの)。
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent.parent
BINARY = HERE / ".build" / "debug" / "Tumble"
KINDS = ["crash", "hang", "threw", "nondeterministic", "sentinel", "nonfinite", "leak", "gpuLeak"]


def build(binary: pathlib.Path | None = None) -> None:
    """組む。`binary` を渡されたら組まずにそれを使う (回している間に組み直しても、走っている
    束の実行ファイルが入れ替わらないように、写しを渡す)。"""
    global BINARY
    if binary:
        BINARY = binary.resolve()
        return
    done = subprocess.run(["swift", "build"], cwd=HERE, capture_output=True, text=True)
    if done.returncode:
        sys.exit(done.stdout[-3000:] + done.stderr[-3000:])


def parse_range(text: str) -> range:
    low, _, high = text.partition("..<")
    if not high:
        raise argparse.ArgumentTypeError("`A..<B` の形で渡す")
    return range(int(low), int(high))


def tail(text: str, lines: int = 6) -> str:
    return "\n".join(text.strip().splitlines()[-lines:])


# MARK: - 回す

def run_batch(seeds: range, stall: float, soak: bool = False) -> tuple[list[dict], int | None, dict | None]:
    """種の束を 1 本の子プロセスで回す。

    (判定の一覧, 次に回す種, 落ちた・止まった記録) を返す。最後まで回れば次の種は None。

    **止まったとみなすのは、出力が `stall` 秒進まなかったとき**である。束全体の制限時間で
    待つと、止まった列が確保を積み続ける間ずっと待つことになる (種 3161 は 130 秒で 21 GB に
    達した)。
    """
    command = [str(BINARY), "--headless", "--seeds", f"{seeds.start}..<{seeds.stop}"] + (["--soak"] if soak else [])
    with tempfile.TemporaryFile("w+") as out, tempfile.TemporaryFile("w+") as err:
        process = subprocess.Popen(command, stdout=out, stderr=err, text=True)
        hung = False
        last_size, last_change = 0, time.time()
        while process.poll() is None:
            time.sleep(0.2)
            size = os.fstat(out.fileno()).st_size
            if size != last_size:
                last_size, last_change = size, time.time()
            elif time.time() - last_change > stall:
                process.kill()
                process.wait()
                hung = True
        out.seek(0)
        err.seek(0)
        lines = [json.loads(line) for line in out.read().splitlines() if line.startswith("{")]
        stderr = err.read()
    outcomes, current = [], None
    for line in lines:
        if "start" in line:
            current = line["start"]
        else:
            outcomes.append(line)
            current = None
    if current is None and not hung and process.returncode == 0:
        return outcomes, None, None
    if not lines:
        # 1 種も名乗らずに終わった。列ではなく起動の失敗なので、種の破れに数えずに止める
        # (実行ファイルだけを写すと、隣の `mokume_MokumeCore.bundle` が無くて毎回落ちる)
        sys.exit(f"起動できない ({process.returncode}):\n{tail(stderr)}")
    if current is None:
        # 名乗る前に落ちた (起動の失敗)。束の頭を記録する
        current = outcomes[-1]["seed"] + 1 if outcomes else seeds.start
    kind = "hang" if hung else "crash"
    record = {"seed": current, "breaks": [kind], "returncode": process.returncode, "stderr": tail(stderr)}
    return outcomes, current + 1, record


def run(args: argparse.Namespace) -> int:
    build(args.binary)
    seeds: range = args.seeds
    started = time.time()
    results: list[dict] = []
    if args.out:
        # 束ごとに書き足す。途中で止めても、そこまでの判定が残る
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text("")
    cursor = seeds.start
    while cursor < seeds.stop:
        batch = range(cursor, min(seeds.stop, cursor + args.batch))
        outcomes, resume, record = run_batch(batch, stall=args.stall, soak=args.soak)
        found = outcomes + ([record] if record else [])
        results += found
        if args.out:
            with args.out.open("a") as handle:
                handle.write("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in found))
        if record:
            print(f"  種 {record['seed']}: {record['breaks'][0]} ({record['returncode']}) {record['stderr'].splitlines()[-1] if record['stderr'] else ''}", flush=True)
        cursor = resume if resume is not None else batch.stop
        done = cursor - seeds.start
        print(f"{done}/{len(seeds)} 種 ({time.time() - started:.0f} 秒)", file=sys.stderr, flush=True)
    print(summary(results, time.time() - started))
    return 0


def summary(results: list[dict], seconds: float) -> str:
    counts = collections.Counter(kind for r in results for kind in r.get("breaks", []))
    broken = [r for r in results if r.get("breaks")]
    ops = sum(r.get("ops", 0) for r in results)
    lines = [f"**{len(results)} 種 ({ops} 口) を {seconds:.0f} 秒で回し、{len(broken)} 種が破れた。**", "",
             "| 破れ | 種の数 | 例 |", "| --- | --- | --- |"]
    for kind in KINDS:
        seeds = [str(r["seed"]) for r in results if kind in r.get("breaks", [])]
        lines.append(f"| `{kind}` | {len(seeds)} | {', '.join(seeds[:8])}{' …' if len(seeds) > 8 else ''} |")
    return "\n".join(lines)


# MARK: - 縮める

def examine(program: dict, timeout: float, soak: bool = False) -> dict:
    """列 1 本を子プロセスで回し、判定を返す。落ちた・止まったものもここで判定に畳む。"""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
        json.dump(program, handle)
        path = handle.name
    try:
        done = subprocess.run([str(BINARY), "--headless", "--program", path] + (["--soak"] if soak else []),
                              capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"breaks": ["hang"]}
    finally:
        os.unlink(path)
    if done.returncode < 0 or (done.returncode and not done.stdout.strip()):
        return {"breaks": ["crash"], "stderr": tail(done.stderr)}
    return json.loads(done.stdout.strip().splitlines()[-1])


def load_program(target: str) -> dict:
    if target.isdigit():
        done = subprocess.run([str(BINARY), "--emit", target], capture_output=True, text=True, check=True)
        return json.loads(done.stdout)
    return json.loads(pathlib.Path(target).read_text())


def ops_of(program: dict) -> list[tuple[str, int, int]]:
    """列の口の在処 (`("setup", 0, i)` か `("frame", f, i)`)。"""
    spots = [("setup", 0, i) for i in range(len(program["setup"]))]
    for f, frame in enumerate(program["frames"]):
        spots += [("frame", f, i) for i in range(len(frame))]
    return spots


def without(program: dict, removed: set[tuple[str, int, int]]) -> dict:
    return {
        "seed": program["seed"],
        "setup": [op for i, op in enumerate(program["setup"]) if ("setup", 0, i) not in removed],
        "frames": [[op for i, op in enumerate(frame) if ("frame", f, i) not in removed]
                   for f, frame in enumerate(program["frames"])],
    }


def shrink(args: argparse.Namespace) -> int:
    build(args.binary)
    program = load_program(args.target)
    kind = args.break_kind
    tries = 0

    def still(candidate: dict) -> bool:
        nonlocal tries
        tries += 1
        return kind in examine(candidate, args.timeout, soak=kind in ("leak", "gpuLeak")).get("breaks", [])

    if not still(program):
        sys.exit(f"この列は `{kind}` で破れない (種か破れの種類を見直す)")

    changed = True
    while changed:
        changed = False
        # フレームを落とす (後ろから。最後の 1 枚は番兵の前に要るので 1 枚は残す)
        for f in reversed(range(len(program["frames"]))):
            if len(program["frames"]) <= 1:
                break
            candidate = dict(program, frames=program["frames"][:f] + program["frames"][f + 1:])
            if still(candidate):
                program, changed = candidate, True
        # 口を落とす (半分ずつの塊から 1 つずつへ)
        size = max(1, len(ops_of(program)) // 2)
        while size >= 1:
            spots = ops_of(program)
            i = 0
            while i < len(spots):
                candidate = without(program, set(spots[i:i + size]))
                if still(candidate):
                    program, changed = candidate, True
                    spots = ops_of(program)
                else:
                    i += size
            size //= 2
        # 端の値をふつうの値へ戻す
        for where, f, i in ops_of(program):
            op = program["setup"][i] if where == "setup" else program["frames"][f][i]
            for k, (arg, tame) in enumerate(zip(op["args"], op["tame"])):
                if arg == tame:
                    continue
                trial = json.loads(json.dumps(program))
                target = trial["setup"][i] if where == "setup" else trial["frames"][f][i]
                target["args"][k] = tame
                if still(trial):
                    program, changed = trial, True
                    op = target

    count = sum(len(frame) for frame in program["frames"]) + len(program["setup"])
    print(f"`{kind}` が出続ける最小の列: {count} 口・{len(program['frames'])} 枚 ({tries} 回試した)", file=sys.stderr)
    text = json.dumps(program, ensure_ascii=False, indent=1) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text)
        swift = subprocess.run([str(BINARY), "--swift", str(args.out)], capture_output=True, text=True).stdout
    else:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            handle.write(text)
        swift = subprocess.run([str(BINARY), "--swift", handle.name], capture_output=True, text=True).stdout
        os.unlink(handle.name)
    print(swift)
    print(json.dumps(examine(program, args.timeout, soak=kind in ("leak", "gpuLeak")), ensure_ascii=False))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)
    runner = commands.add_parser("run", help="種の範囲を回す")
    runner.add_argument("--seeds", type=parse_range, required=True, help="`A..<B`")
    runner.add_argument("--batch", type=int, default=50, help="1 本の子プロセスで回す種の数")
    runner.add_argument("--stall", type=float, default=20, help="出力がこの秒数進まなければ、止まったとみなして殺す")
    runner.add_argument("--out", type=pathlib.Path, help="判定を 1 種 1 行で書く")
    runner.add_argument("--soak", action="store_true", help="判定の代わりに、列を繰り返して漏れを測る (1 種 3 秒前後)")
    runner.set_defaults(handler=run)
    shrinker = commands.add_parser("shrink", help="破れた列を縮める")
    shrinker.add_argument("target", help="種の数字か、列の JSON")
    shrinker.add_argument("--break", dest="break_kind", choices=KINDS, required=True)
    shrinker.add_argument("--timeout", type=float, default=20, help="1 回の試しの猶予 (秒)。越えたら止まったとみなす")
    shrinker.add_argument("--out", type=pathlib.Path, help="縮めた列を書く (`Tumble/Findings/<鍵>.json`)")
    shrinker.set_defaults(handler=shrink)
    for command in (runner, shrinker):
        command.add_argument("--binary", type=pathlib.Path, help="組まずに使う実行ファイル (組み直しても入れ替わらない写し)")
    args = parser.parse_args(argv)
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
