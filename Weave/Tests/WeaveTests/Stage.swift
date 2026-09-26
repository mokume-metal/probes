import CryptoKit
import Foundation
import mokume

@testable import Weave

/// 窓を出さずに `frames` 枚回し、読んだフレームの絵を返す。
///
/// **時計はフレーム番号から導く** (`SketchRuntime` の既定) ので、`frameRate` 30 なら
/// n 枚目の `time` は (n − 1) / 30 秒、`deltaTime` はいつも 1/30 秒である。同じ機械なら
/// 毎回同じ絵が出る。
///
/// - Parameters:
///   - reading: 絵を読むフレーム (1 始まり)。省くと最後の 1 枚だけ。
///   - before: 各フレームを進める直前に呼ぶ。入力を送るのに使う。
@MainActor
func run(
    _ sketch: any Sketch, frames: Int, reading: Set<Int>? = nil, dump: String? = nil,
    on device: RenderDevice = gpu, before: ((Int, SketchRuntime) -> Void)? = nil
) throws -> [Int: Picture] {
    let runtime = try SketchRuntime(sketch: sketch, gpu: device)
    defer { runtime.closePlugins() }
    let wanted = reading ?? [frames]
    var pictures: [Int: Picture] = [:]
    for frame in 1...frames {
        before?(frame, runtime)
        try runtime.advance()
        if wanted.contains(frame) {
            let pixels = try runtime.target.readPixels()
            try fingerprint(pixels, name: dump ?? "unnamed", frame: frame)
            pictures[frame] = Picture(pixels)
        }
    }
    if let dump, let directory = ProcessInfo.processInfo.environment["WEAVE_DUMP"] {
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(dump).png")
        try runtime.target.writePNG(to: url)
    }
    return pictures
}

/// 候補 1 件の 1 経路を回す。読むフレームを省くと全部を読む。
@MainActor
func run(_ key: TangleKey, _ route: Route, frames: Int? = nil, reading: Set<Int>? = nil) throws -> [Int: Picture] {
    let tangle = Tangles.named(key)
    let frames = frames ?? tangle.frames
    return try run(tangle.make(route), frames: frames, reading: reading ?? Set(1...frames), dump: "\(key)-\(route)")
}

@MainActor let gpu = try! RenderDevice()

/// 読み戻した画素。**値は線形・乗算済み**。
struct Picture {
    let pixels: PixelBuffer
    init(_ pixels: PixelBuffer) { self.pixels = pixels }

    var width: Int { pixels.width }
    var height: Int { pixels.height }

    subscript(x: Int, y: Int) -> LinearRGBA { pixels[x, y] }

    /// 条件を満たす画素の数。`columns` / `rows` で調べる範囲を絞れる。
    func count(
        columns: Range<Int>? = nil, rows: Range<Int>? = nil, where test: (LinearRGBA, Int, Int) -> Bool
    ) -> Int {
        var count = 0
        for y in rows ?? 0..<height {
            for x in columns ?? 0..<width where test(self[x, y], x, y) { count += 1 }
        }
        return count
    }

    /// 成分 `value` を被覆とみなした形の、面積と重心。
    func shape(_ value: (LinearRGBA) -> Float) -> (area: Float, centroid: SIMD2<Float>) {
        var (area, moment) = (Float(0), SIMD2<Float>.zero)
        for y in 0..<height {
            for x in 0..<width {
                let w = min(1, max(0, value(self[x, y])))
                area += w
                moment += w * SIMD2(Float(x) + 0.5, Float(y) + 0.5)
            }
        }
        return (area, area > 0 ? moment / area : .zero)
    }

    /// 細かさ `factor` の絵を、`factor` × `factor` の画素の平均で 1 に戻す。
    func downsampled(_ factor: Int) -> [[LinearRGBA]] {
        (0..<height / factor).map { y in
            (0..<width / factor).map { x in
                var sum = SIMD4<Float>.zero
                for dy in 0..<factor {
                    for dx in 0..<factor {
                        let c = self[x * factor + dx, y * factor + dy]
                        sum += [c.red, c.green, c.blue, c.alpha]
                    }
                }
                sum /= Float(factor * factor)
                return LinearRGBA(premultipliedRed: sum.x, green: sum.y, blue: sum.z, alpha: sum.w)
            }
        }
    }
}

/// 2 つの色の、成分ごとの差の最大。
func gap(_ a: LinearRGBA, _ b: LinearRGBA) -> Float {
    max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue), abs(a.alpha - b.alpha))
}

/// 同じ大きさの 2 枚で、差が `threshold` を越える画素の数。
func differing(
    _ a: Picture, _ b: Picture, columns: Range<Int>? = nil, rows: Range<Int>? = nil, threshold: Float = 0.1
) -> Int {
    a.count(columns: columns, rows: rows) { c, x, y in gap(c, b[x, y]) > threshold }
}

/// その場で書いた `draw()` だけのスケッチ。
final class Scene: Sketch {
    var settings: SketchSettings
    let body: (Scene) -> Void
    init(_ settings: SketchSettings = Tangles.settings, _ body: @escaping (Scene) -> Void) {
        self.settings = settings
        self.body = body
    }
    /// `Sketch` が求めるだけで、検査からは呼ばない。
    convenience init() { self.init { _ in } }
    func draw() { body(self) }
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
    let url = URL(fileURLWithPath: directory).appendingPathComponent("Weave-\(getpid()).tsv")
    let line = Data("\(name)\t\(frame)\t\(digest)\n".utf8)
    if !FileManager.default.fileExists(atPath: url.path) {
        try Data().write(to: url)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
}
