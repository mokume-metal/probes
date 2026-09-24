#!/usr/bin/env python3
"""例 1 本ずつの `Package.swift` と `main.swift` を、置き場から組み直す。

    python3 scripts/examples.py          # 書き直す
    python3 scripts/examples.py --check  # 実体とずれていたら 1 で終わる

**157 枚を手で並べない。** 足したのに書き忘れた 1 本は、`mokume watch` で開こうと
するまで気付けない。置き場を見て組み直せば、書き忘れようがない。

## 配置

    Examples/<カテゴリ>/<群>/<例>/
        Package.swift          ここが書く
        Sources/<型名>/
            <例>.swift         移植の実体。**触らない**
            main.swift         ここが書く

**`Sources/` の下に置くのは mokume の都合である。** `mokume watch` が作り直しの
引き金にする世代印は `Package.swift` と `<パッケージ>/Sources` 配下の `.swift`
だけから作られる (mokume の `SourceStamp.swift`)。パッケージ直下に置くと、保存
しても印が変わらず**差し替わらない**。

**モジュール名は例名ではなく型名。** `Basics/Arrays/Array` をモジュール名にすると
`Swift.Array` を隠す。product 名だけ例名にすれば `mokume run` の側は変わらない
(あちらは `products.first { isExecutable }.name` しか見ない)。

**群の空白は詰める** (`Cellular Automata` -> `CellularAutomata`)。打つパスに
クォートが要らなくなる。台帳の例名は原典どおり空白を保つので、対応はここが持つ。

## 版

**`exact` で釘を打ち、値は `Package.resolved` から流す。** 手で書くと
`scripts/bump.py` の正規表現が届かず、版上げの後に**台帳は新しい版・例は古い版**
のまま黙って分岐する。正本を 1 か所に保ち、ずれは `--check` が捕まえる
(`checks.json` の `prepare` から呼ばれるので、verify が必ず通る)。
"""

import json
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "Examples"
SUPPORT = ROOT / "Sources" / "Support" / "Processing.swift"
LEDGER = ROOT / "ledger" / "examples.jsonl"
CLASS = re.compile(r"^(?:final )?class (\w+): Sketch\b", re.MULTILINE)


def squeeze(group: str) -> str:
    """群の名前から空白を詰める。除いた直後は大文字にする。"""
    out: list[str] = []
    upper = False
    for character in group:
        if character == " ":
            upper = True
            continue
        out.append(character.upper() if upper else character)
        upper = False
    return "".join(out)


def groups() -> dict[str, str]:
    """詰めた群名 -> 台帳の群名。**詰めて衝突したら止まる。**"""
    found: dict[str, str] = {}
    for line in LEDGER.read_text().splitlines():
        if not line.strip():
            continue
        example = json.loads(line)["example"]
        parts = example.split("/")
        if len(parts) != 3:
            continue
        key = squeeze(parts[1])
        if found.setdefault(key, parts[1]) != parts[1]:
            raise SystemExit(f"群の名前が詰めると衝突する: {found[key]} と {parts[1]}")
    return found


def pinned() -> str:
    """`Package.resolved` が固定している mokume の版。"""
    for pin in json.loads((ROOT / "Package.resolved").read_text())["pins"]:
        if pin["identity"] == "mokume":
            return pin["state"]["version"]
    raise SystemExit("Package.resolved に mokume が無い")


def symbols() -> re.Pattern[str]:
    """Support が公開している口。使っている例にだけ依存を持たせる。"""
    names = re.findall(r"^public func (\w+)", SUPPORT.read_text(), re.MULTILINE)
    if not names:
        raise SystemExit("Support の口が読めない")
    return re.compile(r"\b(" + "|".join(sorted(set(names))) + r")\s*\(")


def manifest(example: str, kind: str, version: str, support: str | None) -> str:
    """例 1 本の `Package.swift`。"""
    dependencies = [f'.package(url: "https://github.com/mokume-metal/mokume.git", exact: "{version}")']
    products = ['.product(name: "mokume", package: "mokume")']
    if support:
        dependencies.append(f'.package(path: "{support}")')
        products.append('.product(name: "Support", package: "Atlas")')

    lines = [
        "// swift-tools-version: 6.2",
        "",
        "// **生成物** — `python3 scripts/examples.py` が書く。手で編集しない。",
        "//",
        f"// Processing の `{example}` を 1 行ずつ移したもの。走らせ方は:",
        "//",
        "//     mokume run .      # 作って走らせる",
        "//     mokume watch .    # 保存したら作り直して差し替える",
        "//     mokume mcp .      # 走っているスケッチを外から観測する",
        "",
        "import PackageDescription",
        "",
        "let package = Package(",
        f'    name: "{example.split("/")[-1]}",',
        '    platforms: [.macOS("26.0")],',
        f'    products: [.executable(name: "{example.split("/")[-1]}", targets: ["{kind}"])],',
        "    dependencies: [",
    ]
    lines += [f"        {d}," for d in dependencies]
    lines += [
        "    ],",
        "    targets: [",
        "        .executableTarget(",
        f'            name: "{kind}",',
        "            dependencies: [",
    ]
    lines += [f"                {p}," for p in products]
    lines += [
        "            ],",
        "            swiftSettings: [",
        "                // mokume と揃える。既定の隔離が main actor でないと、スケッチに",
        "                // 並行性の注釈が要る",
        "                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),",
        "            ])",
        "    ]",
        ")",
        "",
    ]
    return "\n".join(lines)


def entry(kind: str) -> str:
    """例 1 本の `main.swift`。"""
    return "\n".join([
        "// **生成物** — `python3 scripts/examples.py` が書く。手で編集しない。",
        "//",
        "// **`@main` を移植の側に付けない。** 付けると移植が生成物と混ざるうえ、",
        "// 同じモジュールにトップレベルコードがあると衝突する。`Sketch.main()` は",
        "// `@MainActor static func main()` で、ここ (トップレベルコードも main actor)",
        "// からなら具体型に対して呼べる。",
        "",
        f"{kind}.main()",
        "",
    ])


def collect() -> list[tuple[str, str, pathlib.Path]]:
    """(台帳の例名, 型名, 例のディレクトリ) を置き場から集める。"""
    names = groups()
    found: list[tuple[str, str, pathlib.Path]] = []
    for source in sorted(EXAMPLES.rglob("*.swift")):
        # **生成物は数に入れない。** `Package.swift` も `.swift` なので rglob が拾う。
        # 組み上げた跡 (`.build` / `.swiftpm`) も、例ごとに生えるので避ける
        if source.name in ("main.swift", "Package.swift"):
            continue
        if any(part in (".build", ".swiftpm") for part in source.parts):
            continue
        parts = source.relative_to(EXAMPLES).parts
        if len(parts) != 6 or parts[3] != "Sources":
            raise SystemExit(f"配置が違う: {source.relative_to(ROOT)}")
        category, squeezed, example, _, kind, _ = parts
        if squeezed not in names:
            raise SystemExit(f"台帳に無い群: {category}/{squeezed}")
        found.append((f"{category}/{names[squeezed]}/{example}", kind, source.parent.parent.parent))
    return found


def main(argv: list[str]) -> int:
    checking = "--check" in argv
    version = pinned()
    used = symbols()

    found = collect()
    stale: list[str] = []
    for example, kind, directory in found:
        source = directory / "Sources" / kind / f"{example.split('/')[-1]}.swift"
        matched = CLASS.search(source.read_text())
        if not matched or matched.group(1) != kind:
            raise SystemExit(f"型名がモジュール名と食い違う: {source.relative_to(ROOT)}")

        support = None
        if used.search(source.read_text()):
            support = os.path.relpath(ROOT, directory)

        for target, want in ((directory / "Package.swift", manifest(example, kind, version, support)),
                             (source.parent / "main.swift", entry(kind))):
            if target.exists() and target.read_text() == want:
                continue
            if checking:
                stale.append(str(target.relative_to(ROOT)))
            else:
                target.write_text(want)

    if checking:
        if stale:
            print(f"生成物が置き場とずれている ({len(stale)} 枚):", file=sys.stderr)
            for name in stale[:12]:
                print(f"  {name}", file=sys.stderr)
            if len(stale) > 12:
                print(f"  … 他 {len(stale) - 12} 枚", file=sys.stderr)
            print("\n  python3 scripts/examples.py   # 組み直す", file=sys.stderr)
            return 1
        print(f"{len(found)} 本の生成物は置き場と揃っている (mokume `v{version}`)")
        return 0

    print(f"{len(found)} 本ぶんを組み直した (mokume `v{version}`)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
