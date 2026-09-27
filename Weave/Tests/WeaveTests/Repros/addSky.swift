// repro: mokume#1658
//
// `blendMode(.add)` のままでも、`background(.sky)` は下地を置き換えるはず (色の
// `background()` は混ぜ方を見ずに面を置き換える。`background(.sky)` も「周囲を背景として
// 描く」口)。`blendMode(.blend)` のまま呼んだ絵と、2 枚目を表示の 1 段 (1/255) より小さい
// 差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum AddSky {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let added = try render(Scene(adds: true))
        let blended = try render(Scene(adds: false))
        var differing = 0
        for y in 0..<blended.height {
            for x in 0..<blended.width {
                let (p, q) = (added[x, y], blended[x, y])
                let gap = max(abs(p.red - q.red), abs(p.green - q.green), abs(p.blue - q.blue), abs(p.alpha - q.alpha))
                if gap > 0.004 { differing += 1 }
            }
        }
        guard differing > 0 else { return nil }
        return "2 枚目で \(differing) 画素違う"
            + " ((80, 80) の青: .add \(added[80, 80].blue) / .blend \(blended[80, 80].blue))"
    }

    /// 窓を出さずに 2 枚描いて、2 枚目の画素を読む。
    static func render(_ scene: Scene) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        /// `blendMode(.add)` のまま `background(.sky)` を呼ぶか。
        let adds: Bool
        init(adds: Bool) { self.adds = adds }
        convenience init() { self.init(adds: false) }

        func draw() {
            blendMode(adds ? .add : .blend)
            background(.sky)
            blendMode(.blend)
        }
    }
}
