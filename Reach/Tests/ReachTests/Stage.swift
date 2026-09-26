import CryptoKit
import Foundation
import mokume

@testable import Reach

/// タイル 1 枚を、窓を出さずに描いて画素を返す。
///
/// **`Reach` 自身を 1 タイルの大きさで走らせる** (`Reach.solo`)。窓のタイル
/// (`createGraphics` の面) とは描き先が違い、こちらは本体の面へ直に描く。
/// 時計はフレーム番号から導かれる (`SketchRuntime` の既定) ので、同じ機械なら毎回同じ絵が出る。
@MainActor
enum Stage {
    static let gpu = try! RenderDevice()

    /// 描いた絵。立体の資源は 1 枚目で整うことがあるので 2 枚回してから読む。
    static func render(_ entry: Entry, frames: Int = 2) throws -> PixelBuffer {
        Reach.solo = entry
        defer { Reach.solo = nil }
        let runtime = try SketchRuntime(sketch: Reach(), gpu: gpu)
        for _ in 0..<frames { try runtime.advance() }
        let pixels = try runtime.target.readPixels()
        try fingerprint(pixels, name: entry.reference, frame: frames)
        try shoot(runtime.target, name: entry.reference, frame: frames)
        if let directory = ProcessInfo.processInfo.environment["REACH_DUMP"] {
            let name = entry.reference.map { $0.isLetter || $0.isNumber ? $0 : "_" }
            try runtime.target.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent(String(name) + ".png"))
        }
        runtime.closePlugins()
        return pixels
    }

    /// 窓と同じ格子を、窓を出さずに描く。**タイルは `createGraphics` の面を通る** (窓の経路)。
    static func renderGrid(frames: Int = 2) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Reach(), gpu: gpu)
        for _ in 0..<frames { try runtime.advance() }
        let pixels = try runtime.target.readPixels()
        // 格子は指紋を取らない。値のタイルに、手本どおり種の無い乱数 (`random(array)`) と
        // 実時計 (`second() / hour()`) を映すものがあり、mokume と関わりなく実行ごとに変わる (ADR-0007)
        if let directory = ProcessInfo.processInfo.environment["REACH_DUMP"] {
            try runtime.target.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent("grid.png"))
        }
        runtime.closePlugins()
        return pixels
    }

    /// 下地だけのタイル。**「何も描かなかった」の基準**になる。
    static let blank = Entry(section: .structure, reference: "blank", verdict: .same, mokume: "", tile: .picture { _, _ in })
}

extension PixelBuffer {
    /// 矩形の中で、`color` から `tolerance` を越えて違う画素の数。
    func differing(from color: LinearRGBA, x: Int, y: Int, side: Int, tolerance: Float = 0.02) -> Int {
        var count = 0
        for py in y..<min(y + side, height) {
            for px in x..<min(x + side, width) {
                let a = self[px, py]
                let d = max(abs(a.red - color.red), abs(a.green - color.green), abs(a.blue - color.blue))
                if d > tolerance { count += 1 }
            }
        }
        return count
    }

    /// 2 枚の間で、どれかの成分が `tolerance` を越えて違う画素の数。
    func differing(from other: PixelBuffer, tolerance: Float = 0.02) -> Int {
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let (a, b) = (self[x, y], other[x, y])
                let d = max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue), abs(a.alpha - b.alpha))
                if d > tolerance { count += 1 }
            }
        }
        return count
    }
}

/// 読んだ絵を、環境変数 `PROBES_SHOTS` の置き場へ PNG で書く (`scripts/shots.py` が組み立てる)。
///
/// **`fingerprint` と同じ名前とフレームで書く**ので、指紋の行と絵が 1 対 1 に対応する。mokume へ
/// 起票するときに添える比べる絵の元である (`.claude/skills/probes-evidence/`)。書くのは出す面
/// (`writePNG` = 表示に符号化した絵) で、置き場は `<PROBES_SHOTS>/Reach/<name>-<frame>.png`。
/// 変数が無ければ何もしない。
@MainActor
func shoot(_ target: RenderTarget, name: String, frame: Int) throws {
    guard let root = ProcessInfo.processInfo.environment["PROBES_SHOTS"] else { return }
    let directory = URL(fileURLWithPath: root).appendingPathComponent("Reach", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = String(name.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    try target.writePNG(to: directory.appendingPathComponent("\(file)-\(frame).png"))
}

/// 描いた絵の指紋を、環境変数 `PROBES_FINGERPRINT` の置き場へ 1 行足す (`scripts/stress.py` が読む)。
///
/// **同じフレーム番号からはバイト単位で同じ絵が出る** (mokume ADR-0001 原則 2)。反復・検証レイヤ・
/// 同時実行をまたいで指紋が食い違えば、許容誤差の内に収まるずれでも約束の破れである (ADR-0007)。
/// 変数が無ければ何もしない。
@MainActor
func fingerprint(_ pixels: PixelBuffer, name: String, frame: Int) throws {
    guard let directory = ProcessInfo.processInfo.environment["PROBES_FINGERPRINT"] else { return }
    var hasher = SHA256()
    for y in 0..<pixels.height {
        for x in 0..<pixels.width {
            let c = pixels[x, y]
            for value in [c.red, c.green, c.blue, c.alpha] {
                withUnsafeBytes(of: value.bitPattern) { hasher.update(bufferPointer: $0) }
            }
        }
    }
    let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    let url = URL(fileURLWithPath: directory).appendingPathComponent("Reach-\(getpid()).tsv")
    let line = Data("\(name)\t\(frame)\t\(digest)\n".utf8)
    if !FileManager.default.fileExists(atPath: url.path) {
        try Data().write(to: url)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
}
