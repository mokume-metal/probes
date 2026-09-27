// repro: mokume#1641
//
// `clip` は「描くものを、この矩形の中だけに収める」。画素の格子に乗らない矩形でも、覆う割合が
// 半分に満たない外の画素は描かないはず。`clip(10.9, 0, 10, 40)` で面いっぱいを塗った絵を、
// 同じ矩形を `rect` で塗った絵と、1 行の覆った量と重心で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ClipStaysInside {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let clip = try render { s in
            s.clip(10.9, 0, 10, 40)
            s.rect(0, 0, 100, 40)   // 面いっぱいを塗る
        }
        let rect = try render { s in s.rect(10.9, 0, 10, 40) }
        let (clipArea, clipCenter) = measure(clip)
        let (rectArea, rectCenter) = measure(rect)
        guard Swift.abs(clipArea - rectArea) >= 0.25 || Swift.abs(clipCenter - rectCenter) >= 0.25 else { return nil }
        return "clip(10.9, 0, 10, 40): 1 行の覆った量 \(clipArea)・重心 x \(clipCenter)"
            + " / rect: \(rectArea)・\(rectCenter)"
            + " (画素 10 の赤: clip \(clip[10, 20].red) / rect \(rect[10, 20].red)、"
            + "画素 20 の赤: clip \(clip[20, 20].red) / rect \(rect[20, 20].red))"
    }

    /// 真ん中の行の、赤の総和 (覆った量) と重心 x (画素の中心で測る)。
    static func measure(_ pixels: PixelBuffer) -> (area: Float, center: Float) {
        var (area, moment) = (Float(0), Float(0))
        for x in 0..<pixels.width {
            let w = pixels[x, 20].red
            area += w
            moment += w * (Float(x) + 0.5)
        }
        return (area, area > 0 ? moment / area : 0)
    }

    static func render(_ shape: @escaping (Scene) -> Void) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Scene(shape), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 100, height: 40)
        let shape: (Scene) -> Void
        init(_ shape: @escaping (Scene) -> Void) { self.shape = shape }
        convenience init() { self.init { _ in } }

        func draw() {
            background(0)
            noStroke()
            fill(255)
            shape(self)
        }
    }
}
