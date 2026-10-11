// repro: mokume#2307
//
// `.mov` に書いたフレームの時刻は、fps に依らず 1/fps ずつ等間隔に並ぶはず。`MovieFile` は
// 時刻の刻み (`timescale`) を 90 000 に選び、「端数が出ると、フレームの時刻が刻みへ丸められる
// たびに少しずつずれる」と説明している。48 fps は 90 000 を割り切る (1 枚 1875) ので、1 枚の
// 長さは全部同じになるはず。`frameRate: 48` で 24 枚撮り、`.mov` の `mdhd` (刻み) と `stts`
// (1 枚ごとの長さ) を読んで、長さが揃っているかを見る。
//
// 動画は ProRes 4444 で書かれるので、それを符号化できる機械 (Apple シリコンの Mac) が要る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import Foundation
import mokume

enum MovieTimescale {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let data = try record(fps: 48, frames: 24)
        guard let scale = timescale(data), let deltas = durations(data) else {
            return "mdhd か stts を読めなかった (\(data.count) バイト)"
        }
        let lengths = deltas.flatMap { Array(repeating: $0.delta, count: $0.count) }
        guard Set(lengths).count > 1 || lengths.count != 24 else { return nil }
        return "48 fps で 24 枚撮った .mov: 刻み 1/\(scale)・枚数 \(lengths.count)"
            + "・1 枚の長さ \(Set(lengths).sorted()) 刻み (\(lengths.prefix(8).map(String.init).joined(separator: ", "))…)。"
            + "全部 1/48 秒 (90 000 なら 1875 刻み) で揃うはず"
    }

    /// `frames + 1` 枚回し、1…`frames` 枚目を撮った `.mov` のバイト。
    static func record(fps: Int, frames: Int) throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repro-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let movie = directory.appendingPathComponent("rate.mov")
        let runtime = try SketchRuntime(sketch: Scene(movie.path, fps, frames), gpu: RenderDevice())
        for _ in 0...frames { try runtime.advance() }
        runtime.closePlugins()  // 撮る係を閉じ終えてから返る
        return try Data(contentsOf: movie)
    }

    /// 箱の道 (`moov/trak/…`) を降りて、最後の箱の中身の頭の位置を返す。
    static func find(_ path: [String], in data: Data) -> Int? {
        func word(_ at: Int) -> Int { data[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        var (offset, end) = (data.startIndex, data.endIndex)
        var rest = path[...]
        while offset + 8 <= end, let wanted = rest.first {
            var size = word(offset)
            if size == 1 { size = word(offset + 8) << 32 | word(offset + 12) }  // 64 ビットの大きさ
            guard size >= 8 else { return nil }
            if String(decoding: data[offset + 4..<offset + 8], as: UTF8.self) == wanted {
                rest = rest.dropFirst()
                if rest.isEmpty { return offset + 8 }
                (offset, end) = (offset + 8, offset + size)
            } else {
                offset += size
            }
        }
        return nil
    }

    static func word(_ data: Data, _ at: Int) -> Int { data[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }

    /// 動画のトラックの刻み (`mdhd` の版 0: 版と旗 4・作成 4・更新 4 の後)。
    static func timescale(_ data: Data) -> Int? {
        find(["moov", "trak", "mdia", "mdhd"], in: data).map { word(data, $0 + 12) }
    }

    /// `stts` の (枚数, 長さ) の並び。
    static func durations(_ data: Data) -> [(count: Int, delta: Int)]? {
        guard let body = find(["moov", "trak", "mdia", "minf", "stbl", "stts"], in: data) else { return nil }
        let entries = word(data, body + 4)
        return (0..<entries).map { (word(data, body + 8 + $0 * 8), word(data, body + 12 + $0 * 8)) }
    }

    final class Scene: Sketch {
        var settings: SketchSettings
        let movie: String
        let frames: Int
        init(_ movie: String, _ fps: Int, _ frames: Int) {
            (self.movie, self.frames) = (movie, frames)
            settings = SketchSettings(width: 160, height: 90, frameRate: fps, title: "repro")
        }
        convenience init() { self.init("", 48, 24) }

        func draw() {
            background(40)
            circle(Float(frameCount) * 6, 45, 24)
            if frameCount == 1 { beginRecord(movie) }
            if frameCount == frames + 1 { endRecord() }
        }
    }
}
