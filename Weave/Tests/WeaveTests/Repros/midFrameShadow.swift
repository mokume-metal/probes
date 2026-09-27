// repro: mokume#1656
//
// 影を有効にして立体を置き、フレームの途中で `get()` を読んでから床を置いても、影は同じ
// はず (影の説明「焼き付けはフレームの終わりに 1 度だけ走り」・`loadPixels` の説明「呼んでも
// 絵が 1 画素も変わらない」。`get` も読むだけの口)。`get` を読まない絵と、表示の 1 段
// (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum MidFrameShadow {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let read = try render(Scene(reads: true))
        let plain = try render(Scene(reads: false))
        let differing = count(read, plain)
        guard differing > 0 else { return nil }
        return "フレームの途中で get を読むと、読まない絵と \(differing) 画素違う (床に落ちる影)"
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
        /// 球を置いた後、床を置く前に `get()` を読むか。
        let reads: Bool
        init(reads: Bool) { self.reads = reads }
        convenience init() { self.init(reads: false) }

        func draw() {
            background(0)
            camera(80, -60, 200, 80, 80, 0, 0, 1, 0)
            lights()
            shadows(true)
            noStroke()
            fill(230)
            push()
            translate(80, 60, 0)
            sphere(25)
            pop()
            if reads { _ = get(0, 0) }
            castShadow(false)
            push()
            translate(80, 120, 0)
            box(160, 6, 160)
            pop()
        }
    }
}
