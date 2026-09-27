// repro: mokume#1653
//
// 断片の面 (`surfaces: ["pic": .graphics(layer)]`) に渡した描き場所を、置いた後で同じ
// フレームに描き換えても、先に置いた図形は置いた時点の絵で塗られるはず (`createGraphics`
// の説明「描き換えても、置いた時点の絵が出る」・`texture()` の説明「先に置いた形が、
// 後から描き換えた絵に化けることはない」)。描き換える前に `resetShader()` で列を閉じた絵と、
// 表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ShaderSurfaceRedraw {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let open = try render(Scene(resetsFirst: false))
        let closed = try render(Scene(resetsFirst: true))
        let differing = count(open, closed)
        guard differing > 0 else { return nil }
        // (40, 80) は描き場所が赤のときに置いた左の矩形の中
        let (a, b) = (open[40, 80], closed[40, 80])
        return "先に置いた矩形が、列を閉じてから描き換えた絵と \(differing) 画素違う"
            + " ((40, 80) の赤・青: 閉じない (\(a.red), \(a.blue)) / 閉じる (\(b.red), \(b.blue)))"
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
        /// 描き場所を描き換える前に `resetShader()` で列を閉じるか。
        let resetsFirst: Bool
        var layer: Canvas!
        var paint: Shader!
        init(resetsFirst: Bool) { self.resetsFirst = resetsFirst }
        convenience init() { self.init(resetsFirst: false) }

        func setup() {
            layer = try! createGraphics(160, 160)
            paint = try! makeShader(
                "float4 paint(Fragment in, Values values, Surfaces surfaces) { return mokume_sample(surfaces.pic, in.uv); }",
                surfaces: ["pic": .graphics(layer)])
        }

        func draw() {
            background(0)
            noStroke()
            layer.beginDraw()
            layer.background(255, 0, 0)
            layer.endDraw()
            shader(paint)
            rect(0, 0, 80, 160)  // 赤を置いたつもり
            if resetsFirst { resetShader() }
            layer.beginDraw()
            layer.background(0, 0, 255)
            layer.endDraw()
            resetShader()
            image(layer, 80, 0, 80, 160)
        }
    }
}
