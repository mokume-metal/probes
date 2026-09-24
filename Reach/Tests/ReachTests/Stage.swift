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
