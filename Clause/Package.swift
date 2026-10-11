// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Clause",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Clause", targets: ["Clause"])],
    dependencies: [
        // 他の作品と同じく、**どの版で測ったかは Package.resolved が持つ**。版を上げて
        // 直ったものがあれば、`withKnownIssue` が「起きなかった」で赤くなって知らせる
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.22.1")
    ],
    targets: [
        .executableTarget(
            name: "Clause",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ]),
        // **約束の 1 文を、値・ファイル・ポート・知らせの行で確かめる。** 破れは
        // mokume だけで閉じた再現 (`Repros/`) を `withKnownIssue` で包んで押さえる (README「確かめ方」)
        .testTarget(
            name: "ClauseTests",
            dependencies: ["Clause", .product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]),
    ]
)
