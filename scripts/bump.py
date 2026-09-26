#!/usr/bin/env python3
"""物差しが引く mokume の版を上げる。

    python3 scripts/bump.py 0.7.0              # 全部
    python3 scripts/bump.py 0.7.0 Probe Drift  # 名指し

**`from:` の書き換えは記録であって、留め金ではない。** SwiftPM の `from:` は 0.x を
特別扱いしないので、古いまま置いても `swift package update` は新しい版を拾う
([works#22](https://github.com/mokume-metal/works/pull/22) で実測)。実際に版を固定して
いるのは `Package.resolved` のほうで、`from:` は「どの版を意図しているか」を人が読む
ために書いている。

**中身は 1 行も変えない。** 版だけ動かして基準線を取ると、次に絵が動いたときに
「版差なのか書き直しなのか」を切り分けられる (works#22 → #23 がその形)。
書き直しは別の PR にする。

上げたら、Atlas は `verify.py` で測り直す (**動いた絵の理由を README へ書いてから** `--update`)。
Probe・Drift・Routine・Soak・Aftermath・Imprint・Weave は `swift test` を回す — 赤くなったものは直った約束である。Reach は
`swift test` に加えて、増えた口が穴の行を埋めていないかを見る。
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pieces  # noqa: E402

FROM = re.compile(r'(from:\s*")([0-9]+\.[0-9]+\.[0-9]+)(")')
VERSION = re.compile(r"v?([0-9]+\.[0-9]+\.[0-9]+)")


def version_of(arg: str) -> str:
    """引数を版として検める。**書き換える前に落とす** — 検めないと `--help` まで全部の `from:` へ書き込む (#6)。"""
    found = VERSION.fullmatch(arg)
    if not found:
        raise SystemExit(f"版ではない: {arg!r} (`0.11.2` か `v0.11.2` の形で渡す)\n{__doc__}")
    return found[1]


def rewrite(path: pathlib.Path, version: str) -> str | None:
    """`Package.swift` の `from:`。Garden だけ 3 行に折れているので行では探さない。"""
    manifest = path / "Package.swift"
    text = manifest.read_text()
    found = FROM.findall(text)
    if len(found) != 1:
        raise SystemExit(f"{path.name}/Package.swift の from: が {len(found)} 個ある (1 個を期待)")
    was = found[0][1]
    if was == version:
        return None
    manifest.write_text(FROM.sub(rf"\g<1>{version}\g<3>", text))
    return was


def main(argv: list[str]) -> int:
    if not argv:
        raise SystemExit(__doc__)
    if argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    version, named = version_of(argv[0]), argv[1:]
    targets = [pieces.piece(n) for n in named] if named else pieces.pieces()

    for path in targets:
        was = rewrite(path, version)
        print(f"{path.name}: " + (f"`from:` {was} → {version}" if was else f"`from:` は {version} のまま"))

        done = subprocess.run(["swift", "package", "update", "mokume"],
                              cwd=path, capture_output=True, text=True)
        if done.returncode:
            print(f"  **解決に失敗した**: {done.stderr.strip()[-300:]}")
            continue

        pin = pieces.pinned(path)
        if pin["version"] != version:
            print(f"  **解決したのは v{pin['version']}** — `from:` は上限を締めないので、"
                  "名指しの版より新しいものが降りてくることがある")
        # **台帳を持つものだけ版を書き戻す。** 台帳を持たないものは、
        # 版上げで動くのは `Package.swift` と `Package.resolved` だけである
        if pieces.has_checks(path):
            checks = pieces.load_checks(path)
            checks["mokume"], checks["revision"] = pin["version"], pin["revision"]
            pieces.save_checks(path, checks)
        print(f"  解決: `v{pin['version']}` / `{pin['revision'][:12]}`")

    if any(pieces.has_checks(p) for p in targets):
        print("\n**期待ハッシュはまだ古いままである。** 次に `python3 scripts/verify.py` で測り、"
              "動いた絵の理由を README へ書いてから `--update` で記録を進める。")
    print("\n**Probe・Drift・Routine・Soak・Aftermath・Imprint・Weave は `swift test` を回す。** 赤くなったものは直った約束なので、"
          "`withKnownIssue` を外して README の表を書き換える。")
    print("**Reach も `swift test` を回し、`python3 scripts/api-diff.py` で増えた口が "
          "`none` / `write` / `bend` の行を埋めていないかを見る** (Reach/README「版を上げたら」)。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
