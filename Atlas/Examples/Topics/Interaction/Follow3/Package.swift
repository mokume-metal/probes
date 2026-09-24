// swift-tools-version: 6.2

// **生成物** — `python3 scripts/examples.py` が書く。手で編集しない。
//
// Processing の `Topics/Interaction/Follow3` を 1 行ずつ移したもの。走らせ方は:
//
//     mokume run .      # 作って走らせる
//     mokume watch .    # 保存したら作り直して差し替える
//     mokume mcp .      # 走っているスケッチを外から観測する

import PackageDescription

let package = Package(
    name: "Follow3",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Follow3", targets: ["Follow3"])],
    dependencies: [
        .package(url: "https://github.com/mokume-metal/mokume.git", exact: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Follow3",
            dependencies: [
                .product(name: "mokume", package: "mokume"),
            ],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
