// repro: mokume#1622
//
// 描き場所 (`createGraphics`) で `beginDraw()` をしたまま `endDraw()` を呼ばずにフレームを
// 抜けても、次のフレームの描き直しは前のフレームの変換を引き継がないはず (mokume ADR-0021
// 決定 4: 変換はシーンの記述で、フレームを越えない)。2 枚目で抜けたものと抜けなかったものを
// 別の `SketchRuntime` で 3 枚回し、3 枚目の円の位置を比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum UnclosedDraw {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let skipped = try thirdFrame(skippingEndDraw: true)
        let reference = try thirdFrame(skippingEndDraw: false)
        var differing = 0
        for y in 0..<reference.height {
            for x in 0..<reference.width {
                let (a, b) = (skipped[x, y], reference[x, y])
                let gap = max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue))
                if gap > 0.004 { differing += 1 }
            }
        }
        guard differing > 0 else { return nil }
        return "3 枚目の円の重心 x: 2 枚目で endDraw() せずに抜けたもの \(centroidX(skipped))"
            + " / 抜けなかったもの \(centroidX(reference)) (違う画素 \(differing))"
    }

    /// 窓を出さずに 3 枚回して、3 枚目の画素を読む。
    static func thirdFrame(skippingEndDraw: Bool) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Scene(skippingEndDraw), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        for _ in 1...3 { try runtime.advance() }
        return try runtime.target.readPixels()
    }

    /// 円 (赤の成分が 0.5 を越える画素) の重心の x。
    static func centroidX(_ pixels: PixelBuffer) -> Float {
        var (sum, count) = (Float(0), Float(0))
        for y in 0..<pixels.height {
            for x in 0..<pixels.width where pixels[x, y].red > 0.5 {
                sum += Float(x) + 0.5
                count += 1
            }
        }
        return count > 0 ? sum / count : -1
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        let skippingEndDraw: Bool
        var layer: Canvas!
        init(_ skippingEndDraw: Bool) { self.skippingEndDraw = skippingEndDraw }
        convenience init() { self.init(false) }

        func setup() { layer = try! createGraphics(160, 160) }

        func draw() {
            background(24)
            if frameCount == 2 {
                guard skippingEndDraw else { return }
                layer.beginDraw()
                layer.translate(40, 0)
                return  // endDraw() せずに抜ける
            }
            layer.beginDraw()
            layer.background(LinearRGBA.transparent)
            layer.noStroke()
            layer.fill(240, 140, 40)
            layer.translate(40, 0)
            layer.circle(40, 80, 40)
            layer.endDraw()
            image(layer, 0, 0)
        }
    }
}
