import Foundation
import mokume

@testable import Routine

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
    before: ((Int, SketchRuntime) -> Void)? = nil
) throws -> [Int: Picture] {
    let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
    defer { runtime.closePlugins() }
    let wanted = reading ?? [frames]
    var pictures: [Int: Picture] = [:]
    for frame in 1...frames {
        before?(frame, runtime)
        try runtime.advance()
        if wanted.contains(frame) { pictures[frame] = Picture(try runtime.target.readPixels()) }
    }
    if let dump, let directory = ProcessInfo.processInfo.environment["ROUTINE_DUMP"] {
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(dump).png")
        try runtime.target.writePNG(to: url)
    }
    return pictures
}

/// 候補 1 件の 1 経路を回す。入力を送る候補は、窓と同じ出来事を送る。
@MainActor
func run(_ key: HabitKey, _ route: Route, frames: Int, reading: Set<Int>? = nil) throws -> [Int: Picture] {
    let habit = Habits.named(key)
    return try run(
        habit.make(route), frames: frames, reading: reading, dump: "\(key)-\(route)", before: habit.input)
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
    var settings = Habits.settings
    let body: (Scene) -> Void
    init(_ body: @escaping (Scene) -> Void) { self.body = body }
    /// `Sketch` が求めるだけで、検査からは呼ばない。
    convenience init() { self.init { _ in } }
    func draw() { body(self) }
}
