// repro: mokume#1648
//
// `clip` の中の `background()` は、切り抜きの中だけを塗るはず (`clip` の説明「描くものを、
// この矩形の中だけに収める」。Processing の P2D の `glClear` は scissor に従い、p5 は 2D の
// `clip` の中で `fillRect` する)。切り抜きの中を同じ色の矩形で塗った絵と、表示の 1 段
// (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ClipBackground {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let cleared = try render(Scene(usesBackground: true))
        let painted = try render(Scene(usesBackground: false))
        let differing = count(cleared, painted)
        guard differing > 0 else { return nil }
        // (120, 80) は切り抜き (x < 80) の外で、先に置いた緑の矩形の中
        let (a, b) = (cleared[120, 80], painted[120, 80])
        return "clip の中の background と、同じ色の矩形とで \(differing) 画素違う"
            + " ((120, 80): background (\(a.red), \(a.green), \(a.blue)) / 矩形 (\(b.red), \(b.green), \(b.blue)))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(_ scene: Scene) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    /// 成分の差が表示の 1 段 (1/255) を越える画素の数。
    static func count(_ a: PixelBuffer, _ b: PixelBuffer) -> Int {
        var n = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let (p, q) = (a[x, y], b[x, y])
                let gap = max(abs(p.red - q.red), abs(p.green - q.green), abs(p.blue - q.blue), abs(p.alpha - q.alpha))
                if gap > 0.004 { n += 1 }
            }
        }
        return n
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        /// 切り抜きの中を `background()` で塗るか (偽なら同じ色の矩形で塗る)。
        let usesBackground: Bool
        init(usesBackground: Bool) { self.usesBackground = usesBackground }
        convenience init() { self.init(usesBackground: false) }

        func draw() {
            background(0, 0, 255)
            noStroke()
            fill(0, 255, 0)
            rect(100, 0, 60, 160)  // 切り抜きの外に置く
            clip(0, 0, 80, 160)
            if usesBackground {
                background(255, 0, 0)
            } else {
                fill(255, 0, 0)
                rect(0, 0, 160, 160)
            }
            noClip()
        }
    }
}
