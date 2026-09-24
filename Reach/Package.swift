// swift-tools-version: 6.2

import PackageDescription

// 1 本 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Reach",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Reach", targets: ["Reach"])],
    dependencies: [
        // **どの版で測ったかは Package.resolved が持つ。** 版を上げると、`none` と判定した口が
        // 増えていないかを README の手順で見直す (`scripts/api-diff.py`)
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.11.1")
    ],
    targets: [
        .executableTarget(
            name: "Reach",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ]),
        // **窓を出さずにタイルを 1 枚ずつ描く。** 書けると判定した口が、実際に画素を置くかを
        // 確かめる (README「確かめ方」)
        .testTarget(
            name: "ReachTests",
            dependencies: ["Reach", .product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]),
    ]
)
