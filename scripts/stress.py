#!/usr/bin/env python3
"""画素を見る物差しを、反復・検証レイヤ・同時実行で回して、稀な破れと決定論の破れを捕まえる。

ふだんの `swift test` は、各検査を 1 回・1 プロセス・検証レイヤなしで回す。mokume の
GPU 同期と並行性のバグは稀にしか出ない (mokume#341 は 59 回中 2 回) ので、それでは
構造的に見えない。ここでは同じ検査を条件を変えて何度も回し、次の 2 つを見る
(ADR-0007)。

- **終わり方** — 通過・想定外の失敗・落ちた・止まった・既知の問題の件数のゆれ
- **指紋** — 描いた絵のハッシュ。**同じフレーム番号からはバイト単位で同じ絵が出る**
  (mokume ADR-0001 原則 2) ので、実行をまたいで食い違えば、許容誤差の内のずれでも破れである

    python3 scripts/stress.py                              # Probe Drift Routine Reach を全条件で
    python3 scripts/stress.py Probe --repeat 20 --workers 4
    python3 scripts/stress.py --condition validation       # 条件を絞る

条件:

- `plain`       そのまま `--repeat` 回
- `validation`  Metal の API と GPU の検証レイヤを有効にして `--repeat` 回
- `contention`  同じ物差しを `--workers` 本同時に、それぞれ `--repeat` 回

Soak は対象にしない。時間とメモリの閾値が混雑で狂うためである。

各物差しは最初に 1 度だけ `swift build --build-tests` し、以後は `--skip-build` で回す。
失敗した実行のログと全体の結果 (results.json) は `--out` に残り、要約は Markdown の表で
標準出力へ出る (Issue・PR に貼る形)。何か見つけたら終了コードは 1。
"""

from __future__ import annotations

import argparse
import collections
import concurrent.futures
import dataclasses
import json
import os
import pathlib
import re
import signal
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple

ROOT = pathlib.Path(__file__).resolve().parent.parent
RULERS = ["Probe", "Drift", "Routine", "Reach"]
CONDITIONS: Dict[str, Dict[str, str]] = {
    "plain": {},
    "validation": {"MTL_DEBUG_LAYER": "1", "MTL_SHADER_VALIDATION": "1"},
    "contention": {},
}

# 終わり方の区分。PASS 以外は「見つけた」に数える
PASS = "pass"
FAIL = "fail"
CRASH = "crash"
HANG = "hang"
KNOWN_DRIFT = "known-drift"
STATUSES = [PASS, FAIL, CRASH, HANG, KNOWN_DRIFT]

# 名前とフレームの組 → その実行で出た指紋の並び (同じ組を何度も描く検査があるので多重集合)
Key = Tuple[str, int]
Prints = Dict[Key, Tuple[str, ...]]


@dataclasses.dataclass
class Summary:
    """swift-testing の最後の行 (`Test run with N tests … passed/failed …`)。"""

    tests: int
    passed: bool
    known: int


_RUN_LINE = re.compile(r"Test run with (\d+) tests?\b.*? (passed|failed) after ")
_KNOWN = re.compile(r"(\d+) known issues?")
_SIGNAL = re.compile(r"unexpected signal code (\d+)")


def parse_summary(output: str) -> Optional[Summary]:
    """出力から最後の `Test run with …` の行を読む。無ければ None (途中で終わった)。"""
    for line in reversed(output.splitlines()):
        m = _RUN_LINE.search(line)
        if not m:
            continue
        known = _KNOWN.search(line)
        return Summary(
            tests=int(m.group(1)), passed=m.group(2) == "passed", known=int(known.group(1)) if known else 0
        )
    return None


def classify(returncode: Optional[int], timed_out: bool, output: str, baseline: Optional[int]) -> str:
    """1 回の実行の終わり方を区分する。`baseline` はふだんの既知の問題の件数。"""
    if timed_out:
        return HANG
    if (returncode is not None and returncode < 0) or _SIGNAL.search(output):
        return CRASH
    summary = parse_summary(output)
    if summary is None:
        # 最後の行を書かずに終わった — 落ちたのと同じに扱う
        return CRASH
    if not summary.passed or returncode != 0:
        return FAIL
    if baseline is not None and summary.known != baseline:
        return KNOWN_DRIFT
    return PASS


def read_prints(directory: pathlib.Path) -> Prints:
    """1 回の実行が `PROBES_FINGERPRINT` に書いた指紋を読む。"""
    lines: List[str] = []
    for path in sorted(directory.glob("*.tsv")):
        lines += path.read_text().splitlines()
    return read_prints_from_lines(lines)


def read_prints_from_lines(lines: List[str]) -> Prints:
    """`名前\\tフレーム\\t指紋` の行を読む。同じ組の指紋は並べ替えて多重集合にする
    (並行に走る検査は描く順が実行ごとに入れ替わる)。"""
    found: Dict[Key, List[str]] = collections.defaultdict(list)
    for line in lines:
        if not line:
            continue
        name, frame, digest = line.split("\t")
        found[(name, int(frame))].append(digest)
    return {key: tuple(sorted(digests)) for key, digests in found.items()}


@dataclasses.dataclass
class Mismatch:
    """実行をまたいで指紋が揃わなかった絵 1 枚。"""

    key: Key
    variants: int  # 出た指紋の並びの種類 (欠けも 1 種と数える)
    odd_runs: List[str]  # 多数派と違った実行


def compare_prints(runs: Dict[str, Prints]) -> List[Mismatch]:
    """完走した実行どうしで、名前とフレームごとに指紋の並びを突き合わせる。

    完走した実行は同じ絵をすべて描くはずなので、ある実行にだけ無い絵も食い違いに数える。
    多数派 (同数なら先に出た方) と違った実行を名指しする。
    """
    keys = sorted({key for prints in runs.values() for key in prints})
    mismatches = []
    for key in keys:
        seen = {run: prints.get(key, ()) for run, prints in runs.items()}
        counts = collections.Counter(seen.values())
        if len(counts) <= 1:
            continue
        majority = counts.most_common(1)[0][0]
        odd = sorted(run for run, value in seen.items() if value != majority)
        mismatches.append(Mismatch(key=key, variants=len(counts), odd_runs=odd))
    return mismatches


def max_overlap(spans: List[Tuple[float, float]]) -> int:
    """同時に走っていた実行の最大数。同時実行が本当に重なったかを示す。"""
    events = sorted([(start, 1) for start, _ in spans] + [(end, -1) for _, end in spans])
    current = best = 0
    for _, delta in events:
        current += delta
        best = max(best, current)
    return best


# ---- ここから下は実際に走らせる部分 ----


@dataclasses.dataclass
class Run:
    ruler: str
    condition: str
    index: int
    returncode: Optional[int]
    timed_out: bool
    seconds: float
    started: float
    ended: float
    known: Optional[int]
    status: str = PASS

    @property
    def label(self) -> str:
        return f"{self.condition}#{self.index}"


def build(ruler: str) -> None:
    print(f"== {ruler}: swift build --build-tests", file=sys.stderr)
    # ビルドの出力は標準エラーへ流し、標準出力を要約の表だけにする
    subprocess.run(["swift", "build", "--build-tests"], cwd=ROOT / ruler, check=True, stdout=sys.stderr)


def run_once(ruler: str, condition: str, index: int, out: pathlib.Path, timeout: float) -> Tuple[Run, str]:
    prints = out / "prints" / ruler / f"{condition}-{index}"
    prints.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PROBES_FINGERPRINT=str(prints), **CONDITIONS[condition])
    started = time.time()
    # 時間切れのときに swift と、その下で動くテストの実行体をまとめて止めるため、
    # 自前のプロセスグループで起こす
    process = subprocess.Popen(
        ["swift", "test", "--skip-build"],
        cwd=ROOT / ruler,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )
    timed_out = False
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
    ended = time.time()
    summary = parse_summary(output)
    run = Run(
        ruler=ruler,
        condition=condition,
        index=index,
        returncode=None if timed_out else process.returncode,
        timed_out=timed_out,
        seconds=ended - started,
        started=started,
        ended=ended,
        known=summary.known if summary else None,
    )
    return run, output


def stress(ruler: str, conditions: List[str], repeat: int, workers: int, out: pathlib.Path, timeout: float):
    runs: List[Tuple[Run, str]] = []
    for condition in conditions:
        print(f"== {ruler}: {condition}", file=sys.stderr)
        if condition == "contention":
            total = repeat * workers
            with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                futures = [pool.submit(run_once, ruler, condition, i, out, timeout) for i in range(total)]
                runs += [f.result() for f in futures]
        else:
            runs += [run_once(ruler, condition, i, out, timeout) for i in range(repeat)]

    # ふだんの件数は、最後の行を書いた実行のうちで最も多かった件数とする
    knowns = collections.Counter(run.known for run, _ in runs if run.known is not None)
    baseline = knowns.most_common(1)[0][0] if knowns else None
    for run, output in runs:
        run.status = classify(run.returncode, run.timed_out, output, baseline)
        if run.status != PASS:
            log = out / "logs" / f"{ruler}-{run.condition}-{run.index}.log"
            log.parent.mkdir(parents=True, exist_ok=True)
            log.write_text(output)

    complete = {
        run.label: read_prints(out / "prints" / ruler / f"{run.condition}-{run.index}")
        for run, _ in runs
        if run.status in (PASS, KNOWN_DRIFT)
    }
    mismatches = compare_prints(complete)
    overlap = max_overlap([(r.started, r.ended) for r, _ in runs if r.condition == "contention"])
    return [run for run, _ in runs], baseline, mismatches, overlap


def report(results) -> Tuple[str, bool]:
    lines = [
        "| 物差し | 条件 | 回数 | 通過 | 想定外の失敗 | 落ちた | 止まった | 件数のゆれ | 最長 (秒) |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    found = False
    notes = []
    for ruler, runs, baseline, mismatches, overlap in results:
        conditions = []
        for run in runs:
            if run.condition not in conditions:
                conditions.append(run.condition)
        for condition in conditions:
            group = [r for r in runs if r.condition == condition]
            counts = collections.Counter(r.status for r in group)
            longest = max(r.seconds for r in group)
            name = condition + (f" (最大 {overlap} 本が重なった)" if condition == "contention" else "")
            lines.append(
                f"| {ruler} | {name} | {len(group)} | "
                + " | ".join(str(counts.get(s, 0)) for s in STATUSES)
                + f" | {longest:.1f} |"
            )
            found |= counts.get(PASS, 0) != len(group)
        notes.append(f"- {ruler}: ふだんの既知の問題は {baseline} 件。指紋の食い違いは {len(mismatches)} 枚")
        for m in mismatches:
            found = True
            name, frame = m.key
            total = sum(1 for r in runs if r.status in (PASS, KNOWN_DRIFT))  # 突き合わせた完走の数
            examples = ", ".join(m.odd_runs[:5]) + (" …" if len(m.odd_runs) > 5 else "")
            notes.append(
                f"  - `{name}` の {frame} 枚目: {m.variants} 種。{total} 回中 {len(m.odd_runs)} 回が多数派と違った ({examples})"
            )
    return "\n".join(lines + [""] + notes), found


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("rulers", nargs="*", default=RULERS, help="回す物差し (既定: %(default)s)")
    parser.add_argument("--repeat", type=int, default=5, help="条件ごとの回数 (既定: %(default)s)")
    parser.add_argument("--workers", type=int, default=4, help="contention で同時に回す本数 (既定: %(default)s)")
    parser.add_argument(
        "--condition", default=",".join(CONDITIONS), help="回す条件をカンマで (既定: %(default)s)"
    )
    parser.add_argument("--timeout", type=float, default=600, help="1 回の上限 (秒)。越えたら止まったとみなす")
    parser.add_argument("--out", type=pathlib.Path, default=None, help="ログと結果の置き場 (既定: out-stress/<時刻>)")
    parser.add_argument("--skip-build", action="store_true", help="最初のビルドを飛ばす")
    args = parser.parse_args(argv)

    unknown = [r for r in args.rulers if r not in RULERS]
    conditions = [c for c in args.condition.split(",") if c]
    bad = [c for c in conditions if c not in CONDITIONS]
    if unknown or bad or args.repeat < 1 or args.workers < 1:
        parser.error(f"知らない物差し {unknown} / 条件 {bad}、または回数・本数が 1 未満")

    out = args.out or ROOT / "out-stress" / time.strftime("%Y%m%d-%H%M%S")
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)

    results = []
    for ruler in args.rulers:
        if not args.skip_build:
            build(ruler)
        runs, baseline, mismatches, overlap = stress(ruler, conditions, args.repeat, args.workers, out, args.timeout)
        results.append((ruler, runs, baseline, mismatches, overlap))

    text, found = report(results)
    (out / "results.json").write_text(
        json.dumps(
            [
                {
                    "ruler": ruler,
                    "baseline": baseline,
                    "overlap": overlap,
                    "runs": [dataclasses.asdict(r) for r in runs],
                    "mismatches": [dataclasses.asdict(m) for m in mismatches],
                }
                for ruler, runs, baseline, mismatches, overlap in results
            ],
            ensure_ascii=False,
            indent=2,
        )
    )
    print(text)
    print(f"\nログと結果: {out}", file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
