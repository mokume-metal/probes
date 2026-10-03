// repro: mokume#2027
//
// 1 プロセスで 2 つ目の `SketchApplication.run()` を呼ぶと (Processing の `runSketch` で第 2 窓を
// 出す書き方)、2 つ目は 1 枚も描かず窓も出ない。それだけでなく、**1 つ目が `beginRecord` していた
// `.mov` が開けなくなる** (AVFoundation -11829 "Cannot Open")。2 つ目の `run()` が
// `NSApp.delegate` を差し替え、1 つ目の終了時の後始末が届かないためと見ている。
// 2 つ目を作るだけで `run()` しなければ、`.mov` は 119 枚で開ける。
//
// 動画の書き出しは、終わり方によらず開けるファイルを残す約束である (mokume#1219)。2 つ目を
// 断るなら断ると名乗り、1 つ目の書き出しは守るはずである。
//
// 120 枚目で、道具が止めるときと同じ合図 (SIGTERM) を自分へ送って終わらせる。**終わり方が
// 判定である。** プロセスの終わりに `.mov` の目次 (`moov` の箱) を探し、無ければ終了コード 1 で
// 終わる。AVFoundation を使わずに済ませるため、箱は先頭から辿る。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum SecondApplication {
    nonisolated(unsafe) static var movie = URL(fileURLWithPath: "/")

    /// 戻らない。`.mov` に目次があれば終了コード 0、無ければ 1 で終わる。
    static func reproduce() throws -> String? {
        movie = FileManager.default.temporaryDirectory
            .appendingPathComponent("second-application-\(getpid()).mov")
        atexit {
            guard !SecondApplication.hasIndex(SecondApplication.movie) else { return }
            FileHandle.standardError.write(
                Data("1 つ目の録画に目次 (moov) が無く、開けない: \(SecondApplication.movie.path)\n".utf8))
            _exit(1)
        }
        try SketchApplication(sketch: First(), gpu: RenderDevice()).run()
        return nil
    }

    /// 最上位の箱を辿り、`moov` があるか。
    nonisolated static func hasIndex(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        var offset = 0
        while offset + 8 <= data.count {
            var size = data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
            let kind = String(decoding: data[offset + 4..<offset + 8], as: UTF8.self)
            if kind == "moov" { return true }
            if size == 1, offset + 16 <= data.count {
                size = data[offset + 8..<offset + 16].reduce(0) { $0 << 8 | Int($1) }
            }
            guard size >= 8 else { return false }
            offset += size
        }
        return false
    }

    final class First: Sketch {
        var settings = SketchSettings(width: 200, height: 150, frameRate: 30, title: "repro A")

        func setup() { beginRecord(SecondApplication.movie.path) }

        func draw() {
            background(200, 0, 0)
            circle(Float(frameCount % 200), 75, 20)
            // 第 2 窓を出す書き方。`run()` は戻らず、A の続きのフレームはこの中で回る
            if frameCount == 30 { try? SketchApplication(sketch: Second(), gpu: RenderDevice()).run() }
            // 道具が止めるときと同じ合図で終わらせる
            if frameCount == 120 { kill(getpid(), SIGTERM) }
        }
    }

    final class Second: Sketch {
        var settings = SketchSettings(width: 200, height: 150, frameRate: 30, title: "repro B")

        func draw() { background(0, 0, 200) }
    }
}
