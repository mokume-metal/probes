// repro: mokume#1626
//
// 録画 (`beginRecord("….mov")`) の最中に書けない先への `save()` が 1 度失敗しても、動画は
// 1 枚も欠けないはず (mokume ADR-0025 決定 2: 絵が落ちるのは描けなかったときだけ。ADR-0023
// 決定 2: 出口どうしは互いに独立して書く)。3 枚目から 43 枚目の手前まで撮り、10 枚目で 1 度
// だけ `save()` を失敗させたものと、失敗させないもの (対照) の枚数を、`.mov` の `stsz` 箱
// (標本の数) から読んで比べる。
//
// 動画は ProRes 4444 で書かれるので、それを符号化できる機械 (Apple シリコンの Mac) が要る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import Foundation
import mokume

enum SaveFailureMovie {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let control = try frames(failingSave: false)
        let failing = try frames(failingSave: true)
        guard failing != control else { return nil }
        return "動画に入った枚数: 10 枚目で 1 度 save を失敗させたもの \(failing)"
            + " / 失敗させないもの \(control) (3…42 枚目の 40 枚のはず)"
    }

    /// 45 枚回して書き切らせ、`.mov` に入った枚数を読む。
    static func frames(failingSave: Bool) throws -> Int {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let movie = directory.appendingPathComponent("run.mov")
        let runtime = try SketchRuntime(sketch: Scene(movie.path, failingSave), gpu: RenderDevice())
        for _ in 1...45 { try runtime.advance() }
        runtime.closePlugins()  // 撮る係を閉じ終えてから返る
        return sampleCount(try Data(contentsOf: movie)) ?? -1
    }

    /// `moov/trak/mdia/minf/stbl/stsz` の標本の数 (動画のトラックが 1 本の `.mov`)。
    static func sampleCount(_ data: Data) -> Int? {
        func word(_ at: Int) -> Int { data[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        var (offset, end) = (data.startIndex, data.endIndex)
        var path = ["moov", "trak", "mdia", "minf", "stbl", "stsz"][...]
        while offset + 8 <= end, let wanted = path.first {
            var size = word(offset)
            if size == 1 { size = word(offset + 8) << 32 | word(offset + 12) }  // 64 ビットの大きさ
            guard size >= 8 else { return nil }
            if String(decoding: data[offset + 4..<offset + 8], as: UTF8.self) == wanted {
                path = path.dropFirst()
                if path.isEmpty { return word(offset + 16) }  // 版と旗 4・標本の大きさ 4 の後
                (offset, end) = (offset + 8, offset + size)
            } else {
                offset += size
            }
        }
        return nil
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 90, frameRate: 60, title: "repro")
        let movie: String
        let failingSave: Bool
        init(_ movie: String, _ failingSave: Bool) { (self.movie, self.failingSave) = (movie, failingSave) }
        convenience init() { self.init("", false) }

        func draw() {
            background(40)
            circle(Float(frameCount % 60) * 3, 58, 24)
            if frameCount == 3 { beginRecord(movie) }
            if failingSave && frameCount == 10 { save("/nonexistent-repro/still.png") }  // 書けない先へ 1 度だけ
            if frameCount == 43 { endRecord() }
        }
    }
}
