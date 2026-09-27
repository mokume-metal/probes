// repro: mokume#1657
//
// 立体を置いた後の `background(.sky)` は、`loadPixels()` を挟んでも立体を消して下地を
// 置き換えるはず (`loadPixels` の説明「呼んでも絵が 1 画素も変わらない」)。`loadPixels()` を
// 抜いた絵と、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum LoadPixelsSky {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let loaded = try render(Scene(loads: true))
        let plain = try render(Scene(loads: false))
        let differing = count(loaded, plain)
        guard differing > 0 else { return nil }
        // (80, 80) は立体 (一辺 60 の箱) の中心
        let (a, b) = (loaded[80, 80], plain[80, 80])
        return "loadPixels を挟むと、挟まない絵と \(differing) 画素違う"
            + " ((80, 80): 挟む (\(a.red), \(a.green), \(a.blue)) / 挟まない (\(b.red), \(b.green), \(b.blue)))"
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
        /// 立体を置いた後、`background(.sky)` の前に `loadPixels()` を読むか。
        let loads: Bool
        init(loads: Bool) { self.loads = loads }
        convenience init() { self.init(loads: false) }

        func draw() {
            lights()
            fill(255)
            push()
            translate(80, 80, 0)
            box(60)
            pop()
            if loads { loadPixels() }
            background(.sky)
        }
    }
}
