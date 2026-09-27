// repro: mokume#1654
//
// `beginDraw()` / `endDraw()` で囲まずに描き場所へ `set()` した画素も、`image()` で出るはず
// (`set` の説明「1 画素の色を書き換える」。読む口の `get` は書いた値を返す)。囲んで書いた
// 絵と、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum GraphicsSetOutside {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let outside = Scene(wrapped: false)
        let bare = try render(outside)
        let wrapped = try render(Scene(wrapped: true))
        let differing = count(bare, wrapped)
        guard differing > 0 else { return nil }
        // (40, 80) は赤を書いた左半分の中
        return "囲まずに書いた画素が、囲んで書いた絵と \(differing) 画素違う"
            + " ((40, 80) の赤: image \(bare[40, 80].red) / get \(outside.layer.get(40, 80).red)"
            + " / 囲んだときの image \(wrapped[40, 80].red))"
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
        /// `set` の列を `beginDraw()` / `endDraw()` で囲むか。
        let wrapped: Bool
        var layer: Canvas!
        init(wrapped: Bool) { self.wrapped = wrapped }
        convenience init() { self.init(wrapped: false) }

        func setup() {
            layer = try! createGraphics(160, 160)
            if wrapped { layer.beginDraw() }
            for y in 0..<160 {
                for x in 0..<80 { layer.set(x, y, color(255, 0, 0)) }
            }
            if wrapped { layer.endDraw() }
        }

        func draw() {
            background(0)
            image(layer, 0, 0)
        }
    }
}
