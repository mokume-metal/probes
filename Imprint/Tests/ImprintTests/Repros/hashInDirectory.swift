// repro: mokume#未起票
//
// 連番の番号は、名前の `#` の並びに入るはず (`beginRecord` の説明)。置き場のディレクトリの名前に
// `#` があっても (`take#1/`・`C#/`)、番号の場所はファイル名の側である。`take#1/f-##.png` へ 3 枚
// 撮り、`take#1/` に `f-00.png`…`f-02.png` が入るかを見る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import Foundation
import mokume

enum HashInDirectory {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("repro-\(UUID().uuidString)", isDirectory: true)
        let take = root.appendingPathComponent("take#1", isDirectory: true)
        try FileManager.default.createDirectory(at: take, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let runtime = try SketchRuntime(
            sketch: Scene(take.appendingPathComponent("f-##.png").path), gpu: RenderDevice())
        for _ in 1...5 { try runtime.advance() }
        runtime.closePlugins()  // 撮る係を閉じ終えてから返る

        let inside = try FileManager.default.contentsOfDirectory(atPath: take.path).sorted()
        guard inside != ["f-00.png", "f-01.png", "f-02.png"] else { return nil }
        let beside = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        let found = beside.map { name -> String in
            let path = root.appendingPathComponent(name).path
            let files = (try? FileManager.default.contentsOfDirectory(atPath: path).sorted()) ?? []
            return files.isEmpty ? name : "\(name)/{\(files.joined(separator: ","))}"
        }
        return "take#1/f-##.png へ 3 枚撮ると、take#1/ の中は \(inside)。置き場の隣は \(found)"
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 32, height: 32, frameRate: 30, title: "repro")
        let pattern: String
        init(_ pattern: String) { self.pattern = pattern }
        convenience init() { self.init("") }

        func draw() {
            background(Float(frameCount * 40))
            if frameCount == 1 { beginRecord(pattern) }
            if frameCount == 4 { endRecord() }
        }
    }
}
