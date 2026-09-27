// repro: mokume#1652
//
// 本体で作った断片を描き場所で使い、`set` を挟んで 2 つ描いても、`set` より前に置いた図形は
// 前の値のまま描かれるはず (どの面で使っても同じ)。描き場所で作った断片で同じことをした
// 絵と、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ShaderSetGraphics {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let main = try render(Scene(madeOnLayer: false))
        let layer = try render(Scene(madeOnLayer: true))
        let differing = count(main, layer)
        guard differing > 0 else { return nil }
        // (40, 80) は k = 1 で塗ったはずの左半分
        return "本体で作った断片が、描き場所で作った断片と \(differing) 画素違う"
            + " ((40, 80) の赤: 本体の断片 \(main[40, 80].red) / 描き場所の断片 \(layer[40, 80].red))"
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
        /// 断片を描き場所で作るか (偽なら本体で作る)。
        let madeOnLayer: Bool
        var layer: Canvas!
        var paint: Shader!
        init(madeOnLayer: Bool) { self.madeOnLayer = madeOnLayer }
        convenience init() { self.init(madeOnLayer: false) }

        func setup() {
            layer = try! createGraphics(160, 160)
            let source = "float4 paint(Fragment in, Values values) { return float4(values.k, 0, 0, 1); }"
            paint = madeOnLayer
                ? try! layer.makeShader(source, values: ["k": 0])
                : try! makeShader(source, values: ["k": 0])
        }

        func draw() {
            background(0)
            layer.beginDraw()
            layer.background(0)
            layer.noStroke()
            layer.shader(paint)
            paint.set("k", 1)
            layer.rect(0, 0, 80, 160)
            paint.set("k", 0.25)
            layer.rect(80, 0, 80, 160)
            layer.resetShader()
            layer.endDraw()
            image(layer, 0, 0)
        }
    }
}
