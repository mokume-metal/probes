#!/usr/bin/env python3
"""原典と mokume の公開 API を取ってくる。

**取ってきたものはリポジトリへコミットしない。** 250 例のうち 34 例は原作者に著作権が
残り (Processing の examples/README.md)、data/ の資材にはライセンス表記が無い。
再現に要るのは中身ではなく「どの版から読んだか」なので、それを ledger/sources.json
へ刻んで、中身は upstream/ (gitignore 済み) へ置く。

    python3 scripts/fetch.py

版を上げるときは下の PIN を書き換える (**上流は sha で釘を打ってある**)。
ledger/sources.json の差分がそのまま「何が変わって台帳を組み直したか」の記録になる。
"""

import json
import pathlib
import subprocess
import sys
import tarfile
import tempfile

# 取ってくる版。**ここだけが上流への参照**で、他のスクリプトは upstream/ しか読まない
#
# **ref は枝ではなく sha で打つ。** 台帳は 2 つの軸で見直す — mokume が上がったら
# vocabulary.jsonl、Processing が上がったら examples.jsonl (README「2 つに割ってあるのは、
# 片方だけ見直せるようにするため」)。ref を "main" にしておくと、mokume の版を上げただけの
# つもりで回しても Processing 側が一緒に進み、**動いたのがどちらの版差なのか言えなくなる**。
# 上げるときは、ここを新しい sha へ書き換えるのが上げる意思表示になる。
PIN = {
    # 例の正本。processing-docs は非推奨 (README が「will be archived soon」と名乗る)
    "examples": {"repo": "processing/processing-examples", "ref": "b10c9e9a05a0d6c20d233ca7f30d315b5047720e"},
    # リファレンスの項目名。組み込みの語彙かどうかの判定に使う
    "reference": {"repo": "processing/processing-website", "ref": "1fce63d07182becca614b95ab76b3b1416424d8d"},
    # 定数の正本。リファレンスに項目が無いので (PI ほか 5 つを除く) ここから引く
    "constants": {"repo": "processing/processing4", "ref": "0d8bde55f71764f4c6091beab7881fcb00738d20"},
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream"

sys.path.insert(0, str(ROOT.parent / "scripts"))
import mokume_api  # noqa: E402
import pieces  # noqa: E402


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def resolve(repo: str, ref: str) -> str:
    """ブランチ名を、いま指しているコミットの SHA へ畳む。"""
    return json.loads(gh("api", f"repos/{repo}/commits/{ref}"))["sha"]


def fetch_examples(
    repo: str, sha: str, into: pathlib.Path, manifest_path: pathlib.Path,
    with_assets: set[str] | None = None,
) -> int:
    """例の .pde を取り出す。**資材は要る例のぶんだけ。**

    資材 (data/ の画像・フォント・モデル) にはライセンス表記が無いので、
    **リポジトリへはコミットしない** (`upstream/` は gitignore 済み)。かつては 1 つも
    取らずパスだけ数えていたが、移した例を実際に走らせるには手元に要る — 絵を読む
    例が絵を読めないと、面が空になったことが mokume の欠けなのか資材が無いだけなのか
    区別が付かない。**再配布はしないまま、走らせるためだけに置く。**

    `with_assets` を渡すと、その例の `data/` だけを取り出す (公式ページに載る
    162 本ぶん)。どの例が資材を要るかは、これまでどおり manifest が数える。
    """
    into.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict] = {}
    wanted = with_assets or set()
    with tempfile.NamedTemporaryFile(suffix=".tar.gz") as tmp:
        subprocess.run(
            ["gh", "api", f"repos/{repo}/tarball/{sha}"], stdout=tmp, check=True
        )
        tmp.flush()
        count = 0
        with tarfile.open(tmp.name) as tar:
            for member in tar.getmembers():
                if not member.isfile():
                    continue
                parts = pathlib.Path(member.name).parts[1:]
                # <カテゴリ>/<小分類>/<例>/… の下だけを見る
                if len(parts) < 4:
                    continue
                example = "/".join(parts[:3])
                entry = manifest.setdefault(example, {"assets": 0, "shaders": 0})
                if parts[-1].endswith(".pde") and len(parts) == 4:
                    target = into.joinpath(*parts)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    source = tar.extractfile(member)
                    if source is None:
                        continue
                    target.write_bytes(source.read())
                    count += 1
                else:
                    entry["assets"] += 1
                    if parts[-1].endswith((".glsl", ".vert", ".frag")):
                        entry["shaders"] += 1
                    if example in wanted and parts[3] == "data":
                        target = into.joinpath(*parts)
                        target.parent.mkdir(parents=True, exist_ok=True)
                        source = tar.extractfile(member)
                        if source is not None:
                            target.write_bytes(source.read())
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    return count


def fetch_reference_names(repo: str, sha: str, into: pathlib.Path) -> int:
    """リファレンスの項目名。**中身は要らないのでファイル名だけ取る。**"""
    tree = json.loads(gh("api", f"repos/{repo}/git/trees/{sha}?recursive=1"))
    prefix = "content/references/translations/en/processing/"
    names = sorted(
        pathlib.Path(item["path"]).stem
        for item in tree["tree"]
        if item["type"] == "blob"
        and item["path"].startswith(prefix)
        and item["path"].endswith(".json")
    )
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text("\n".join(names) + "\n")
    return len(names)


def fetch_site_examples(repo: str, sha: str, into: pathlib.Path) -> dict[str, int]:
    """**公式ページに載っている例**と、その原典として何が配られているかを記録する。

    `processing/processing-examples` は 254 本を持つが、[Examples のページ]
    (https://processing.org/examples/) に並ぶのはそのうち 162 本だけである
    (Demos 92 本と、`Curves` / `Shaders` / `Geometry` / `Textures` /
    `Create Shapes` はページに出ない)。ページは site の `content/examples/` を
    そのまま歩いて組まれるので、**この木がページの正本**になる。

    併せて、例ごとに**原典として走らせられるもの**を見る:

        live  `liveSketch.js` がある (Processing 版と 1 行ずつ対応した p5.js)。156 本
        png   静止画しか無い。site はこの 1280x720 の絵を代わりに見せている。6 本

    比べる相手がどちらかで測り方が変わる (png は縮めるので一致率が参考値になる) ため、
    どちらなのかは台帳が持つべき事実である。
    """
    tree = json.loads(gh("api", f"repos/{repo}/git/trees/{sha}?recursive=1"))
    prefix = "content/examples/"
    listing: dict[str, dict] = {}
    for item in tree["tree"]:
        path = item["path"]
        if not path.startswith(prefix):
            continue
        parts = path[len(prefix):].split("/")
        # <カテゴリ>/<群>/<例>/<ファイル> の下だけを見る
        if len(parts) != 4:
            continue
        entry = listing.setdefault("/".join(parts[:3]), {"origin": "png"})
        if parts[3] == "liveSketch.js":
            entry["origin"] = "live"
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text(json.dumps(listing, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    live = sum(1 for e in listing.values() if e["origin"] == "live")
    return {"examples": len(listing), "live": live}


def fetch_constants(repo: str, sha: str, into: pathlib.Path) -> int:
    """PConstants.java から定数名を起こす。

    **リファレンスには CENTER も TRIANGLE_STRIP も HSB も項目が無い** (項目化されて
    いるのは PI / HALF_PI / QUARTER_PI / TWO_PI / TAU の 5 つだけ)。Ring が実際に
    詰まったのは TRIANGLE_STRIP なので、ここを落とすと台帳が最も重要な穴を見落とす。
    """
    import re

    path = "core/src/processing/core/PConstants.java"
    body = gh("api", f"repos/{repo}/contents/{path}?ref={sha}", "--jq", ".content")
    import base64

    source = base64.b64decode(body).decode("utf-8", errors="replace")
    # **PConstants は interface なので `static final` が省いてある** (`int HSB = 3;`)。
    # 修飾子を要求すると 6 件しか採れない
    names = sorted(set(re.findall(
        r"^\s*(?:public\s+|static\s+|final\s+)*(?:int|float|char|String|boolean|double|long)(?:\[\])?\s+([A-Z][A-Z0-9_]+)\s*=",
        source, re.M)))
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text("\n".join(names) + "\n")
    return len(names)


def fetch_mokume_api(into: pathlib.Path) -> tuple[str, int]:
    """mokume の公開 API 一覧。**版は Package.resolved が決める** (作品の作法)。

    一覧はリポジトリに置かれず Release 資産として配られる (mokume ADR-0001 原則 8)。
    取り口はリポジトリ直下の `scripts/mokume_api.py` に置いてある — **台帳の判定と
    版上げの `api-diff.py` が同じ一覧を見ている**ことが、こうしていないと保てない。
    """
    version = pieces.pinned(ROOT)["version"]
    body = mokume_api.text(version)
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text(body)
    return version, len(body.splitlines())


def main() -> int:
    UPSTREAM.mkdir(exist_ok=True)
    sources: dict[str, object] = {}

    for key, pin in PIN.items():
        sha = resolve(pin["repo"], pin["ref"])
        sources[key] = {"repo": pin["repo"], "sha": sha}
        print(f"{pin['repo']} @ {sha[:12]}", file=sys.stderr)

    # **ページの一覧を先に取る。** 資材をどの例のぶんだけ取るかがこれで決まる
    counts = fetch_site_examples(PIN["reference"]["repo"], sources["reference"]["sha"], UPSTREAM / "site-examples.json")
    sources["reference"]["site_examples"] = counts["examples"]
    sources["reference"]["site_live"] = counts["live"]
    print(f"  公式ページの例を {counts['examples']} 本 (うち p5 を配るもの {counts['live']} 本)", file=sys.stderr)
    on_site = set(json.loads((UPSTREAM / "site-examples.json").read_text()))

    n = fetch_examples(
        PIN["examples"]["repo"], sources["examples"]["sha"],
        UPSTREAM / "examples", UPSTREAM / "manifest.json", with_assets=on_site,
    )
    sources["examples"]["pde_files"] = n
    print(f"  例の .pde を {n} 本", file=sys.stderr)

    n = fetch_reference_names(PIN["reference"]["repo"], sources["reference"]["sha"], UPSTREAM / "reference-names.txt")
    sources["reference"]["entries"] = n
    print(f"  リファレンスの項目名を {n} 件", file=sys.stderr)

    n = fetch_constants(PIN["constants"]["repo"], sources["constants"]["sha"], UPSTREAM / "constants.txt")
    sources["constants"]["entries"] = n
    print(f"  定数を {n} 件", file=sys.stderr)

    version, lines = fetch_mokume_api(UPSTREAM / "mokume-api.md")
    sources["mokume"] = {"version": version, "lines": lines}
    print(f"  mokume v{version} の公開 API ({lines} 行)", file=sys.stderr)

    out = ROOT / "ledger" / "sources.json"
    out.write_text(json.dumps(sources, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"\n刻んだ: {out.relative_to(ROOT)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
