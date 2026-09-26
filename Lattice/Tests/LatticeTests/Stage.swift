import CryptoKit
import Foundation
import Testing
import mokume

@testable import Lattice

@MainActor let gpu = try! RenderDevice()

/// 窓を出さずに `frames` 枚回し、最後のフレームの**出す面** (効果と拡大を通した絵) を読む。
///
/// **時計はフレーム番号から導く** (`SketchRuntime` の既定) ので、n 枚目の `time` は
/// (n − 1) / fps 秒、`deltaTime` はいつも 1 / fps 秒である。
///
/// - Parameter region: 読む範囲。省くと面の全体。大きな面 (16384 画素) の全体を 1 画素ずつ
///   値に移すと数分かかるので、関係に要る所だけを読む。
@MainActor
func run(_ scene: Scene, frames: Int = 1, name: String, region: Region? = nil) throws -> Picture {
    let runtime = try SketchRuntime(sketch: scene, gpu: gpu)
    defer { runtime.closePlugins() }
    for _ in 0..<frames { try runtime.advance() }
    let buffer = try runtime.target.readPixels()
    let picture = Picture(buffer, region ?? Region(x: 0, y: 0, width: buffer.width, height: buffer.height))
    try fingerprint(picture, name: name, frame: frames)
    try shoot(runtime.target, name: name, frame: frames)
    if let directory = ProcessInfo.processInfo.environment["LATTICE_DUMP"] {
        try runtime.target.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
    return picture
}

/// 1 枚目の `draw()` の終わりに、スケッチの側から**描く面** (`pixels`・細かさを掛けた
/// 大きさ・効果と拡大の前) を読む。
@MainActor
func runDrawn(_ settings: SketchSettings, name: String, _ body: @escaping (Scene) -> Void) throws -> Picture {
    final class Holder { var picture: Picture? }
    let holder = Holder()
    let runtime = try SketchRuntime(
        sketch: Scene(settings) { s in
            body(s)
            s.loadPixels()
            holder.picture = Picture(s.pixels)
        }, gpu: gpu)
    defer { runtime.closePlugins() }
    try runtime.advance()
    let picture = try #require(holder.picture)
    try fingerprint(picture, name: name, frame: 1)
    // 読んだのは draw() の中の描く面 (効果と拡大の前)。後から書ける出す面とは中身が
    // 違うので、shoot は通さない (指紋と絵の 1 対 1 が崩れる)
    return picture
}

struct Region {
    let x: Int, y: Int, width: Int, height: Int
}

/// 読み戻した画素。**値は線形・乗算済み**。範囲の外を読むと `nil`。
struct Picture {
    let width: Int
    let height: Int
    /// 行ごとに、画素ごとに赤・緑・青・不透明度。
    let values: [SIMD4<Float>]

    init(width: Int, height: Int, values: [SIMD4<Float>]) {
        self.width = width
        self.height = height
        self.values = values
    }

    init(_ buffer: PixelBuffer, _ region: Region) {
        width = region.width
        height = region.height
        var values = [SIMD4<Float>]()
        values.reserveCapacity(region.width * region.height)
        buffer.components.withUnsafeBufferPointer { c in
            for y in region.y..<region.y + region.height {
                var base = (y * buffer.width + region.x) * 4
                for _ in 0..<region.width {
                    values.append(SIMD4(Float(c[base]), Float(c[base + 1]), Float(c[base + 2]), Float(c[base + 3])))
                    base += 4
                }
            }
        }
        self.values = values
    }

    @MainActor init(_ pixels: Pixels) {
        width = pixels.width
        height = pixels.height
        var values = [SIMD4<Float>]()
        values.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let c = pixels[x, y]
                values.append(SIMD4(c.red, c.green, c.blue, c.alpha))
            }
        }
        self.values = values
    }

    subscript(x: Int, y: Int) -> SIMD4<Float>? {
        x >= 0 && y >= 0 && x < width && y < height ? values[y * width + x] : nil
    }

    /// 出 (x, y) に、入 `source(x, y)` を置いた絵。入が範囲の外なら `nil` の画素 (比べない)。
    func mapped(_ source: (Int, Int) -> (Int, Int)) -> [SIMD4<Float>?] {
        var out = [SIMD4<Float>?]()
        out.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let (sx, sy) = source(x, y)
                out.append(self[sx, sy])
            }
        }
        return out
    }

    func crop(_ region: Region) -> Picture {
        var values = [SIMD4<Float>]()
        for y in region.y..<region.y + region.height {
            for x in region.x..<region.x + region.width { values.append(self[x, y]!) }
        }
        return Picture(width: region.width, height: region.height, values: values)
    }

    /// 赤の成分の総和 (白い図形なら、覆った面積)。
    var light: Float { values.reduce(0) { $0 + $1.x } }

    /// 下地より明るい画素の数。関係を比べる前に、何かが描けていることを押さえる。
    var lit: Int { values.count { max($0.x, $0.y, $0.z) > 0.2 } }

    /// 赤の成分を被覆とみなした形の重心 (画素の中心で測る)。
    var centroid: SIMD2<Float> {
        var (area, moment) = (Float(0), SIMD2<Float>.zero)
        for y in 0..<height {
            for x in 0..<width {
                let w = values[y * width + x].x
                area += w
                moment += w * SIMD2(Float(x) + 0.5, Float(y) + 0.5)
            }
        }
        return area > 0 ? moment / area : .zero
    }
}

/// 2 つの色の、成分ごとの差の最大。
func gap(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> Float {
    // `abs` と `-` は mokume の多重定義と曖昧になるので、成分ごとに書く
    Swift.max(Swift.abs(a.x - b.x), Swift.abs(a.y - b.y), Swift.abs(a.z - b.z), Swift.abs(a.w - b.w))
}

/// 比べた結果。範囲の外から写した画素は数えない。
struct Difference: CustomStringConvertible {
    var over: Int = 0
    var largest: Float = 0
    var at: (x: Int, y: Int) = (0, 0)
    var description: String { "\(over) 画素が違う (最大 \(largest)・(\(at.x), \(at.y)))" }
}

/// 同じ大きさの 2 枚で、差が `threshold` を越える画素。
func difference(_ a: Picture, _ b: [SIMD4<Float>?], threshold: Float) -> Difference {
    var result = Difference()
    for y in 0..<a.height {
        for x in 0..<a.width {
            guard let other = b[y * a.width + x] else { continue }
            let g = gap(a.values[y * a.width + x], other)
            if g > threshold { result.over += 1 }
            if g > result.largest { (result.largest, result.at) = (g, (x, y)) }
        }
    }
    return result
}

func difference(_ a: Picture, _ b: Picture, threshold: Float) -> Difference {
    precondition(a.width == b.width && a.height == b.height, "\(a.width)×\(a.height) と \(b.width)×\(b.height)")
    return difference(a, b.values.map { $0 }, threshold: threshold)
}

/// 読んだ絵を、環境変数 `PROBES_SHOTS` の置き場へ PNG で書く (`scripts/shots.py` が組み立てる)。
///
/// **`fingerprint` と同じ名前とフレームで書く**ので、指紋の行と絵が 1 対 1 に対応する。mokume へ
/// 起票するときに添える比べる絵の元である (`.claude/skills/probes-evidence/`)。書くのは出す面
/// (`writePNG` = 表示に符号化した絵) で、置き場は `<PROBES_SHOTS>/Lattice/<name>-<frame>.png`。
/// 変数が無ければ何もしない。
@MainActor
func shoot(_ target: RenderTarget, name: String, frame: Int) throws {
    guard let root = ProcessInfo.processInfo.environment["PROBES_SHOTS"] else { return }
    let directory = URL(fileURLWithPath: root).appendingPathComponent("Lattice", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = String(name.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    try target.writePNG(to: directory.appendingPathComponent("\(file)-\(frame).png"))
}

/// 描いた絵の指紋を、環境変数 `PROBES_FINGERPRINT` の置き場へ 1 行足す (`scripts/stress.py` が読む)。
///
/// **同じフレーム番号からはバイト単位で同じ絵が出る** (mokume ADR-0001 原則 2)。反復・検証レイヤ・
/// 同時実行をまたいで指紋が食い違えば、許容誤差の内に収まるずれでも約束の破れである (ADR-0007)。
/// 読んだ範囲だけを通す。変数が無ければ何もしない。
func fingerprint(_ picture: Picture, name: String, frame: Int) throws {
    guard let directory = ProcessInfo.processInfo.environment["PROBES_FINGERPRINT"] else { return }
    var hasher = SHA256()
    for value in picture.values {
        for component in [value.x, value.y, value.z, value.w] {
            withUnsafeBytes(of: component.bitPattern) { hasher.update(bufferPointer: $0) }
        }
    }
    let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    let url = URL(fileURLWithPath: directory).appendingPathComponent("Lattice-\(getpid()).tsv")
    let line = Data("\(name)\t\(frame)\t\(digest)\n".utf8)
    if !FileManager.default.fileExists(atPath: url.path) {
        try Data().write(to: url)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
}
