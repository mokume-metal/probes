// repro: mokume#1628
//
// 同じ入力から書き出した `.mov` は、ファイルのバイトまで一致するはず (`MovieFile` と
// `Sketch+Save` の説明、mokume ADR-0025 の表「バイト単位で一致」)。同じスケッチを 2 回、
// 1.1 秒あけて (違う秒に落ちるように) 書き出し、違うバイトがどの箱のどこにあるかを数える。
//
// 動画は ProRes 4444 で書かれるので、それを符号化できる機械 (Apple シリコンの Mac) が要る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import Foundation
import mokume

enum MovieBytes {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let first = try record()
        Thread.sleep(forTimeInterval: 1.1)
        let second = try record()
        guard first != second else { return nil }
        guard first.count == second.count else {
            return "長さが違う: \(first.count) / \(second.count) バイト"
        }
        let offsets = first.indices.filter { first[$0] != second[$0] }
        let places = offsets.map { offset -> String in
            let (kind, start) = box(containing: offset, in: first)
            return "\(kind)+\(offset - start) (\(first[offset]) → \(second[offset]))"
        }
        return "1.1 秒あけて 2 回書き出した \(first.count) バイトのうち \(offsets.count) バイトが違う: "
            + places.joined(separator: "・")
    }

    /// 20 枚回し、1…19 枚目を撮った `.mov` のバイト。
    static func record() throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let movie = directory.appendingPathComponent("twice.mov")
        let runtime = try SketchRuntime(sketch: Scene(movie.path), gpu: RenderDevice())
        for _ in 1...20 { try runtime.advance() }
        runtime.closePlugins()  // 撮る係を閉じ終えてから返る
        return try Data(contentsOf: movie)
    }

    /// `offset` を含む最も内側の箱の種類と、その箱の頭の位置。
    static func box(containing offset: Int, in data: Data) -> (String, Int) {
        func word(_ at: Int) -> Int { data[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        var (start, end, found) = (0, data.count, ("?", 0))
        while start + 8 <= end {
            var size = word(start)
            if size == 1 { size = word(start + 8) << 32 | word(start + 12) }  // 64 ビットの大きさ
            if size == 0 { size = end - start }
            guard size >= 8 else { break }
            let kind = String(decoding: data[start + 4..<start + 8], as: UTF8.self)
            if offset < start + size {
                found = (kind, start)
                guard ["moov", "trak", "mdia", "minf", "stbl"].contains(kind) else { break }
                (start, end) = (start + 8, start + size)  // 入れ物の箱へ降りる
            } else {
                start += size
            }
        }
        return found
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 90, frameRate: 60, title: "repro")
        let movie: String
        init(_ movie: String) { self.movie = movie }
        convenience init() { self.init("") }

        func draw() {
            background(40)
            circle(Float(frameCount % 60) * 3, 58, 24)
            if frameCount == 1 { beginRecord(movie) }
            if frameCount == 20 { endRecord() }
        }
    }
}
