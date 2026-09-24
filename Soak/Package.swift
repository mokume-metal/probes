// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Soak",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Soak", targets: ["Soak"])],
    dependencies: [
        // 他の作品と同じく、**どの版で測ったかは Package.resolved が持つ**。版を上げて
        // 直ったものがあれば、`withKnownIssue` が「起きなかった」で赤くなって知らせる
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.11.1")
    ],
    targets: [
        .executableTarget(
            name: "Soak",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ]),
        // **窓を出さずに長く回して、メモリ・重さ・落ちるかを数で押さえる。** 候補ごとに
        // 2 つの経路を回し、増え方と時間を比べる (README「確かめ方」)
        .testTarget(
            name: "SoakTests",
            dependencies: ["Soak", .product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]),
    ]
)
