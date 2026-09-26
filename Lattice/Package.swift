// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Lattice",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Lattice", targets: ["Lattice"])],
    dependencies: [
        // 他の作品と同じく、**どの版で測ったかは Package.resolved が持つ**。版を上げて
        // 直ったものがあれば、`withKnownIssue` が「起きなかった」で赤くなって知らせる
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "Lattice",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ]),
        // **窓を出さずに描いて画素を読む。** 条件を振った絵どうしを、成り立つはずの
        // 関係 (鏡映・回転・切り抜き・縮小…) で比べる (README「何をしているか」)
        .testTarget(
            name: "LatticeTests",
            dependencies: ["Lattice", .product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)]),
    ]
)
