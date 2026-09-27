// repro: mokume#1627
//
// 同じ名前へ毎フレーム `save()` すると、最後に残るのは最後に頼んだフレームの絵のはず
// (`Sketch+Save` の説明: `save` は呼んだフレームの絵を書く。mokume#927)。30 枚回して
// `latest.png` に置き続けるのを 1 試行とし、残ったファイルのバイトを、名前を毎回変えて
// 書かせた各フレームの PNG (こちらは順序に左右されない) と突き合わせる。
//
// **崩れは、機械が空いていると稀である** (1 試行あたり数百回に 1 回)。混んでいるほど出やすい
// ので、コアの数だけ空回りするスレッドで機械を混ませたうえで試行を `trials` 回繰り返し、
// 1 回でも崩れたら破れとする。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import Foundation
import mokume

enum SameNameSave {
    static let trials = 20
    static let frames = 30

    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let gpu = try RenderDevice()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repro-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // 各フレームの絵の PNG。名前が毎回違うので、書く順序が崩れても置き換わらない
        let each = directory.appendingPathComponent("each")
        try run(gpu) { each.appendingPathComponent("f-\($0).png").path }
        let pictures = try (1...frames).map { try Data(contentsOf: each.appendingPathComponent("f-\($0).png")) }
        // 機械を混ませる。崩れは、書く仕事がすぐに走れないときほど出やすい (mokume は触らない)
        let load = (0..<ProcessInfo.processInfo.activeProcessorCount).map { _ in
            Thread { while !Thread.current.isCancelled {} }
        }
        load.forEach { $0.start() }
        defer { load.forEach { $0.cancel() } }
        var left: [Int] = []  // 崩れた試行で残っていた絵の番号
        for trial in 1...trials {
            let file = directory.appendingPathComponent("trial-\(trial)/latest.png")
            try run(gpu) { _ in file.path }
            let bytes = try Data(contentsOf: file)
            if bytes != pictures[frames - 1] { left.append((pictures.firstIndex(of: bytes) ?? -2) + 1) }
        }
        guard !left.isEmpty else { return nil }
        return "\(trials) 試行のうち \(left.count) 回、latest.png が \(frames) 枚目の絵でなかった"
            + " (残っていた絵の番号: \(left.map(String.init).joined(separator: ", ")))"
    }

    /// `frames` 枚回し、各フレームで `name(frameCount)` へ `save` する。閉じて書き切らせる。
    static func run(_ gpu: RenderDevice, name: @escaping (Int) -> String) throws {
        let runtime = try SketchRuntime(sketch: Scene(name), gpu: gpu)
        for _ in 1...frames { try runtime.advance() }
        runtime.closePlugins()  // 頼んだ書き込みを書き切ってから返る
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 90, frameRate: 60, title: "repro")
        let name: (Int) -> String
        init(_ name: @escaping (Int) -> String) { self.name = name }
        convenience init() { self.init { _ in "" } }

        func draw() {
            background(40)
            circle(Float(frameCount % 60) * 3, 58, 24)
            save(name(frameCount))
        }
    }
}
