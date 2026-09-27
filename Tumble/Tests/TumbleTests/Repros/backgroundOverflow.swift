// repro: mokume#未起票
//
// 白を越える明るさの `background(40000)` の上に、不透明な青い矩形を描くと、矩形の中が NaN になり、表示では
// 黒く抜ける。`background` が色を締めずに Float16 の面へ置き、面が +inf を持つため (inf × 0 = NaN)。
// 混ぜ方 `.blend` は後から描いた不透明なものが前を覆う約束なので、矩形の中は下地の明るさによらず
// 同じ青になるはず。`background(255)` と `background(20000)` では青く出る。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum BackgroundOverflowRepro {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let bright = try render(Scene(ground: 40000))
        let white = try render(Scene(ground: 255))
        var differing = 0
        for y in 10..<30 {
            for x in 10..<30 {
                let (p, q) = (bright[x, y], white[x, y])
                let gap = max(abs(p.red - q.red), abs(p.green - q.green), abs(p.blue - q.blue), abs(p.alpha - q.alpha))
                if !(gap <= 0.004) { differing += 1 }
            }
        }
        guard differing > 0 else { return nil }
        let a = bright[20, 20]
        let b = white[20, 20]
        return "background(40000) の上の不透明な矩形の \(differing) / 400 画素が、background(255) の上と違う"
            + " ((20, 20): (\(a.red), \(a.green), \(a.blue), \(a.alpha)) / (\(b.red), \(b.green), \(b.blue), \(b.alpha)))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(_ scene: Scene) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 40, height: 40, frameRate: 30, title: "repro")
        /// 下地の明るさ (0–255 の目盛り。255 を越えると白を越える明るさ)。
        let ground: Float
        init(ground: Float) { self.ground = ground }
        convenience init() { self.init(ground: 40000) }

        func draw() {
            background(ground)
            noStroke()
            fill(40, 90, 230)
            rect(10, 10, 20, 20)
        }
    }
}
