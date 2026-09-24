import Foundation
import mokume

@testable import Probe

/// 候補 1 件の 1 経路を、窓を出さずに描いて画素を返す。
///
/// **時計はフレーム番号から導く** (`SketchRuntime` の既定) ので、同じ機械なら毎回同じ絵が
/// 出る。描くのは本体の面で、窓のタイル (`createGraphics` の面) とは経路が違う。
@MainActor
final class Stage: Sketch {
    static var current: (Case, Route)?

    var settings = SketchSettings(width: Probes.side, height: Probes.side, title: "stage")

    init() {}

    func draw() {
        guard let (probe, route) = Self.current else { return }
        probe.draw(canvas, route)
    }

    static let gpu = try! RenderDevice()

    /// 描いた絵。`frames` 枚回してから読む (立体の資源は 1 枚目で整うことがあるため 2 枚)。
    static func render(_ probe: Case, _ route: Route, frames: Int = 2) throws -> Picture {
        current = (probe, route)
        defer { current = nil }
        let runtime = try SketchRuntime(sketch: Stage(), gpu: gpu)
        for _ in 0..<frames { try runtime.advance() }
        let picture = Picture(try runtime.target.readPixels())
        if let directory = ProcessInfo.processInfo.environment["PROBE_DUMP"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(probe.key)-\(route).png")
            try runtime.target.writePNG(to: url)
        }
        runtime.closePlugins()
        return picture
    }
}

/// 読み戻した画素。**値は線形・乗算済み**なので、比べるときは下の口を通す。
struct Picture {
    let pixels: PixelBuffer
    init(_ pixels: PixelBuffer) { self.pixels = pixels }

    var width: Int { pixels.width }
    var height: Int { pixels.height }

    subscript(x: Int, y: Int) -> LinearRGBA { pixels[x, y] }

    /// 画素ごとの輝度 (線形)。
    func luminance(_ x: Int, _ y: Int) -> Float {
        let c = self[x, y]
        return 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue
    }

    /// 全画素の輝度の和。
    var totalLuminance: Float {
        var sum: Float = 0
        for y in 0..<height { for x in 0..<width { sum += luminance(x, y) } }
        return sum
    }

    /// 2 枚の間で、どれかの成分が `tolerance` を越えて違う画素の数。
    func differing(from other: Picture, tolerance: Float = 0.02) -> Int {
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let (a, b) = (self[x, y], other[x, y])
                let color: Float = max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue))
                let d: Float = max(color, abs(a.alpha - b.alpha))
                if d > tolerance { count += 1 }
            }
        }
        return count
    }
}

extension Picture {
    /// `x` 列の `y0..<y1` の赤の和 (線形)。縦線の濃さを量る。
    func redSum(row y: Int, columns: Range<Int>) -> Float {
        columns.reduce(0) { $0 + self[$1, y].red }
    }

    /// 輝度が `threshold` を越える画素のうち、いちばん右の列。無ければ -1。
    func rightmostInk(threshold: Float = 0.3) -> Int {
        for x in stride(from: width - 1, through: 0, by: -1) {
            for y in 0..<height where luminance(x, y) > threshold { return x }
        }
        return -1
    }
}

/// 1 経路だけの絵を、その場で書いた描き方から作る。
@MainActor
func sketch(_ body: @escaping @MainActor (Canvas) -> Void) throws -> Picture {
    try Stage.render(Case(key: .hairline, title: "", solid: false) { s, _ in body(s) }, .suspect)
}
