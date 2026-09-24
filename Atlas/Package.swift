// swift-tools-version: 6.2

import PackageDescription

// **Atlas は走らせるものではなくなった。** 例 1 本ずつが独立した SwiftPM パッケージ
// を持ち (`Examples/<カテゴリ>/<群>/<例>/`)、`mokume run` / `watch` / `mcp` はその
// 1 本を直に指す。ここに executable は無い。
//
//     mokume watch Examples/Basics/Input/Mouse2D
//
// **それでもこの `Package.swift` が要る理由は 2 つある。**
//
// 1. **例が引く共有の面を持つ** — Processing にあって mokume に無い語彙のうち、
//    面の外に書けば済むものを `Sources/Support/Processing.swift` へ集めてある。
//    45 本がこれを引く。実体を 1 か所に保つと、**何本の例がそれを要求したか**が
//    数えられる (作品ごとに書き下すと、同じ 1 行が 45 回書かれるだけで消える)
// 2. **版の正本を持つ** — `Package.resolved` がどの mokume で描いたかを固定する。
//    probes の道具 (`scripts/pieces.py` ほか) は「直下に `Package.swift` を持つ
//    ディレクトリ」を 1 作品として数えるので、これが無いと Atlas は版上げの監視
//    からも検証からも外れる。例 157 枚の `exact` はここから流し込まれる
//    (`scripts/examples.py`)
let package = Package(
    name: "Atlas",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Support", targets: ["Support"])],
    dependencies: [
        // **`from` で宣言する。** 例の側は `exact` で釘を打つが、そちらの値は
        // `Package.resolved` から流し込まれる。こちらまで `exact` にすると、
        // 食い違った日に解決できなくなる
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "Support",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
