#!/usr/bin/env python3
"""原典の語彙を抜き出し、mokume の公開 API と突き合わせて台帳を組む。

    python3 scripts/fetch.py     # 先に上流を取ってくる
    python3 scripts/ledger.py    # ledger/ を組み直す

**この台帳は予測であって検証ではない。** 見ているのは名前と定数だけなので、同名で
当たってしまう違い (引数の形・既定値・振る舞い) は写らない。Ring が踏んだ 4 つの
うち機械が見つけられるのは 2 つで、残り 2 つは実際に移して初めて出た。だから
vocabulary.jsonl は**移した作品が書き足す台帳**として持ち、実測が増えるほど
判定が正確になる。

判定 (vocabulary.jsonl の verdict)。**上の 4 つは届く、下の 3 つが穴**:

    same     mokume に同名がある。機械が置く (人手で覆せる)
    renamed  口はあるが別名・別の形 (CENTER → ShapeMode.center)
    host     mokume ではなく Swift / Foundation の語彙で当たる (PI → Float.pi)
    drop     原典にはあるが mokume では要らない (P3D — 描き方のモードを持たない)
    write    面に無いが、面の外にユーザーコードで書ける (map / radians / dist)
    bend     書けるが歪む。原典の形が保てない (TRIANGLE_STRIP / mousePressed())
    none     口が無い (loadFont / loadStrings)

**write と bend を分けるのが肝。** どちらも「mokume に無い」だが、前者は不便なだけ、
後者は原典の構造が壊れる。ADR-0022 決定 3 が Feature Issue に求める「書けなかったか、
書けたが歪んだか」がこの区別そのものである。

行が無いものは**未判定**。番人の値を置かないのは、集計側が数え忘れて静かに嘘の
数字を出すのを防ぐため — 未判定を含む例は届く / 届かないのどちらにも数えない。

**`none` はさらに 2 つに割れる** (vocabulary.jsonl の blocks)。並べて比べられるか
どうかは、この区別で決まる:

    picture    絵そのものが出ない (loadShape — 形が来ないので面が空になる)
    structure  絵は出るが構造が壊れる (noLoop — 1 度で止まらないだけで、絵は同じ)

`class` が blocked の例も、止めているのが structure だけなら**歪めれば絵は出る**。
例ごとの picture 欄がそれを持つ (draws / bent / none)。
"""

import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

sys.path.insert(0, str(ROOT.parent / "scripts"))
import mokume_api  # noqa: E402
UPSTREAM = ROOT / "upstream"
LEDGER = ROOT / "ledger"

# 制御構文。`識別子 + (` で拾うと混ざるので落とす
CONTROL = {"if", "for", "while", "switch", "catch", "return", "new", "else", "do", "synchronized"}

# **Processing が「定義させる」語彙。** 書く側が `void mousePressed()` と書くので
# 宣言の除外に飲まれるが、定義していること自体がその語彙を使っている証拠である。
# ここを守らないと、Garden が踏んだ最重要の欠け (mokume#723) が台帳の上で消える。
CALLBACKS = {
    "setup", "draw", "settings", "exit", "dispose",
    "mousePressed", "mouseReleased", "mouseDragged", "mouseMoved", "mouseClicked", "mouseWheel",
    "keyPressed", "keyReleased", "keyTyped",
}

# 測らないと決めたもの。**理由を持たせて残す** — 台帳から消すと「測っていない」と
# 「測ったが届かない」の区別が付かなくなる
OUT_OF_SCOPE = {
    "Topics/Shaders": "GLSL を書く例。mokume のシェーダは Metal なので語彙の対応にならない",
    "Demos/Performance": "性能測定。絵ではなく速さが主題",
    "Demos/Tests": "処理系の試験。作品ではない",
    "Topics/File IO": "ファイル入出力が主題。mokume は読み書きの口を持たない (Foundation を直に使う)",
    "Topics/Advanced Data": "データ構造とネットワークが主題",
    "Basics/Web": "ブラウザ向けの出力が主題",
}


def strip_source(text: str) -> str:
    """コメントと文字列リテラルを落とす。"""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    text = re.sub(r'"(\\.|[^"\\])*"', " ", text)
    return re.sub(r"'(\\.|[^'\\])*'", " ", text)


def local_names(source: str) -> set[str]:
    """**その例の中で**宣言された識別子。

    例をまたいで集めてはいけない — 別の例が自前の `constrain` を宣言しているせいで、
    本物の組み込みを使っている例からその語彙が消える。
    """
    names = set(re.findall(r"\bclass\s+([A-Za-z_]\w*)", source))
    names |= set(re.findall(r"\binterface\s+([A-Za-z_]\w*)", source))
    # 戻り値型 + 名前 ( → メソッドの宣言
    names |= set(re.findall(r"\b(?:void|int|float|boolean|String|char|double|long|byte|[A-Z]\w*)\s+([a-z_]\w*)\s*\(", source))
    # 型 + 名前 ; = [ → 変数・フィールドの宣言
    names |= set(re.findall(r"\b[A-Z]\w*(?:\[\])?\s+([a-z_]\w*)\s*[;=\[,)]", source))
    return names - CALLBACKS


def load_reference() -> set[str]:
    """Processing のリファレンスの項目名を、呼べる名前へ均す。

    ファイル名の綴りは `ellipse_` (関数) / `PVector` (クラス) / `PVector_add_`
    (メソッド) / `mousePressed` (変数) の 4 通り。末尾の _ とクラス名の前置きを外す。
    """
    names: set[str] = set()
    for line in (UPSTREAM / "reference-names.txt").read_text().split():
        stem = line.rstrip("_")
        names.add(stem)
        if "_" in stem:
            names.add(stem.split("_")[-1])   # PVector_add → add
            names.add(stem.split("_")[0])    # PVector_add → PVector
    return names


def load_mokume_api() -> set[str]:
    """mokume の公開 API 一覧 (Release 資産の Markdown) から名前を起こす。

    起こし方はリポジトリ直下の `scripts/mokume_api.py` が持つ。**版上げのときに
    「何が増えたか」を数える口と同じもの**を使う — 別々に書くと、台帳が穴と数えて
    いるものと差分が増えたと言うものが静かにずれる。
    """
    return mokume_api.names((UPSTREAM / "mokume-api.md").read_text())


def load_vocabulary() -> dict[str, dict]:
    path = LEDGER / "vocabulary.jsonl"
    if not path.exists():
        return {}
    out = {}
    for line in path.read_text().splitlines():
        if line.strip():
            row = json.loads(line)
            out[row["name"]] = row
    return out


def credit_of(head: str) -> str | None:
    """ヘッダのクレジット行。**PD かどうかを分ける唯一の手掛かり。**

    Processing の examples/README.md いわく「クレジット行の無いものと Daniel Shiffman
    のものはパブリックドメイン。他は原作者に著作権が残る」。移せるのは前者だけ。
    """
    match = re.search(r"^\s*(?:\*|//)?\s*(?:by\s+|Created by\s+)([A-Z][A-Za-z.'\- ]+)", head, re.M)
    if not match:
        return None
    who = match.group(1).strip().rstrip(".")
    return None if "Shiffman" in who else who


def main() -> int:
    if not UPSTREAM.exists():
        print("upstream/ が無い。先に scripts/fetch.py を走らせる", file=sys.stderr)
        return 1

    reference = load_reference()
    constants = set((UPSTREAM / "constants.txt").read_text().split())
    mokume = load_mokume_api()
    vocabulary = load_vocabulary()
    manifest = json.loads((UPSTREAM / "manifest.json").read_text())
    # 公式ページに載る 162 本と、その原典 (p5 が配られるか / 静止画だけか)
    site = json.loads((UPSTREAM / "site-examples.json").read_text())

    rows = []
    demand: dict[str, list[str]] = collections.defaultdict(list)

    for name in sorted(manifest):
        entry = manifest[name]
        files = sorted((UPSTREAM / "examples").glob(f"{name}/*.pde"))
        if not files:
            continue
        raw = "\n".join(f.read_text(encoding="utf-8", errors="replace") for f in files)
        source = strip_source(raw)
        local = local_names(source)

        calls = set(re.findall(r"([A-Za-z_]\w*)\s*\(", source)) - CONTROL - local
        used_constants = set(re.findall(r"\b([A-Z][A-Z0-9_]{1,})\b", source)) & constants
        # 例の中で宣言された static final は組み込みではない
        declared_constants = set(re.findall(r"\bstatic\s+final\s+\w+\s+([A-Z][A-Z0-9_]+)", source))
        used_constants -= declared_constants

        # 組み込みの語彙だけを残す (Java 標準・自前のクラスのメソッドは測らない)
        vocab = sorted((calls & reference) | (calls & CALLBACKS))
        group = "/".join(name.split("/")[:2])

        verdicts = collections.Counter()
        unknown = []
        blocks = collections.Counter()
        for word in vocab + sorted(used_constants):
            known = vocabulary.get(word)
            if known:
                verdicts[known["verdict"]] += 1
                if known["verdict"] == "none":
                    blocks[known.get("blocks", "picture")] += 1
            elif word in mokume:
                verdicts["same"] += 1
            else:
                unknown.append(word)
                demand[word].append(name)

        if group in OUT_OF_SCOPE:
            klass = "out-of-scope"
        elif unknown:
            klass = "unknown"
        elif verdicts["none"]:
            klass = "blocked"
        elif verdicts["bend"]:
            klass = "bend"
        elif verdicts["write"]:
            klass = "write-only"
        else:
            klass = "clean"

        # **並べて比べられるか。** class とは別の軸である — blocked でも、止めているのが
        # 構造だけなら絵は出るので原典と並べられる (noLoop の例がまさにそれ)。
        # 未判定を含む例は picture も決めない (数え忘れて嘘を出さないため)
        if unknown:
            picture = None
        elif blocks["picture"]:
            picture = "none"
        elif blocks["structure"]:
            picture = "bent"
        else:
            picture = "draws"

        head = "\n".join(f.read_text(encoding="utf-8", errors="replace")[:1200] for f in files)
        credit = credit_of(head)
        rows.append({
            "example": name,
            "group": group,
            # 公式ページ (processing.org/examples/) に載るか。載るものだけが比較の対象
            "site": name in site,
            # 原典として何が配られているか。live = p5、png = 静止画のみ、null = ページに無い
            "origin": site.get(name, {}).get("origin"),
            "picture": picture,
            "files": len(files),
            "lines": sum(1 for line in raw.splitlines() if line.strip()),
            "assets": entry.get("assets", 0),
            "license": "credited" if credit else "pd",
            "credit": credit,
            "class": klass,
            "verdicts": dict(sorted(verdicts.items())),
            "vocabulary": vocab,
            "constants": sorted(used_constants),
            "unknown": unknown,
        })

    LEDGER.mkdir(exist_ok=True)
    with (LEDGER / "examples.jsonl").open("w") as out:
        for row in rows:
            out.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")

    # 需要 — **まだ判定していない語彙を、何本の例が要求しているか順に**。
    # 次にどの語彙を埋めるか / どの例を移すかは、この順で決まる
    with (LEDGER / "demand.jsonl").open("w") as out:
        for word, examples in sorted(demand.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            in_scope = [e for e in examples if "/".join(e.split("/")[:2]) not in OUT_OF_SCOPE]
            out.write(json.dumps({
                "name": word,
                "examples": len(examples),
                "in_scope": len(in_scope),
                "where": sorted(examples)[:8],
            }, ensure_ascii=False, sort_keys=True) + "\n")

    # 語彙ごとの需要。**何本の例がそれを要求するか**が、穴の重みになる
    weight: dict[str, set[str]] = collections.defaultdict(set)
    for row in rows:
        if row["class"] == "out-of-scope":
            continue
        for word in row["vocabulary"] + row["constants"]:
            weight[word].add(row["example"])

    classes = collections.Counter(r["class"] for r in rows)
    order = ["clean", "write-only", "bend", "blocked", "out-of-scope", "unknown"]
    label = {
        "clean": "そのまま届く", "write-only": "書けば届く", "bend": "書けるが歪む",
        "blocked": "口が無くて止まる", "out-of-scope": "測らないと決めた", "unknown": "未判定を含む",
    }

    lines = ["| 区分 | 例数 | |", "| --- | ---: | --- |"]
    for k in order:
        if classes[k]:
            lines.append(f"| `{k}` | {classes[k]} | {label[k]} |")
    lines.append(f"| **合計** | **{len(rows)}** | |")
    lines.append("")

    # **公式ページの 162 本だけを取り出した内訳。** 台帳は 254 本を平等に扱うが、
    # 人が「Processing の Examples」と呼ぶのはページに並ぶこちらである
    on_site = [r for r in rows if r["site"]]
    pictures = collections.Counter(r["picture"] for r in on_site)
    origins = collections.Counter(r["origin"] for r in on_site)
    picture_label = {
        "draws": "そのまま絵が出る", "bent": "歪めれば絵は出る",
        "none": "絵が出せない", None: "未判定を含む",
    }
    lines.append(f"公式ページに載る {len(on_site)} 本を、**原典と並べられるか**で分けたもの。")
    lines.append("")
    lines.append("| 並べられるか | 例数 | |")
    lines.append("| --- | ---: | --- |")
    for k in ["draws", "bent", "none", None]:
        if pictures[k]:
            lines.append(f"| `{k or 'unknown'}` | {pictures[k]} | {picture_label[k]} |")
    lines.append(f"| **合計** | **{len(on_site)}** | |")
    lines.append("")
    lines.append(
        f"原典は {origins['live']} 本が p5 (`liveSketch.js`)、{origins['png']} 本は"
        " site が置く静止画だけ。")
    lines.append("")
    lines.append("| 何本の例を止めるか | 語彙 | 判定 | mokume では |")
    lines.append("| ---: | --- | --- | --- |")
    holes = [
        (len(examples), word, vocabulary[word])
        for word, examples in weight.items()
        if word in vocabulary and vocabulary[word]["verdict"] in {"write", "bend", "none"}
    ]
    for count, word, row in sorted(holes, key=lambda h: (-h[0], h[1]))[:20]:
        issue = f" ([#{row['issue']}](https://github.com/mokume-metal/mokume/issues/{row['issue']}))" if row.get("issue") else ""
        lines.append(f"| {count} | `{word}` | `{row['verdict']}`{issue} | {row.get('mokume') or '—'} |")

    (LEDGER / "summary.md").write_text("\n".join(lines) + "\n")

    print(f"例 {len(rows)} 本を組んだ", file=sys.stderr)
    for k in order:
        if classes[k]:
            print(f"  {k:14s} {classes[k]:4d}  {label[k]}", file=sys.stderr)
    print(f"未判定の語彙 {len(demand)} 個 (ledger/demand.jsonl)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
