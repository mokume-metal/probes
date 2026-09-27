// repro: mokume#1646
//
// `createShape { }` の中で変えた `curveDetail` は、組み立ての外の曲線に効かないはず
// (`createShape` の実装は「記録の間に触った状態は外へ出さない」と名乗る)。中で
// `curveDetail(2)` を呼んだ絵と、呼ばない絵を、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ShapeCurveDetail {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let leaked = try render(Scene(changesDetail: true))
        let plain = try render(Scene(changesDetail: false))
        let differing = count(leaked, plain)
        guard differing > 0 else { return nil }
        return "createShape の中で curveDetail(2) を呼ぶと、外の曲線が \(differing) 画素違う"
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
        /// `createShape` の中で `curveDetail(2)` を呼ぶか。
        let changesDetail: Bool
        init(changesDetail: Bool) { self.changesDetail = changesDetail }
        convenience init() { self.init(changesDetail: false) }

        func draw() {
            background(0)
            _ = createShape {
                if changesDetail { curveDetail(2) }
                rect(0, 0, 10, 10)
            }
            noFill()
            stroke(255)
            strokeWeight(4)
            beginShape()
            vertex(20, 130)
            bezierVertex(20, 20, 140, 20, 140, 130)
            endShape()
        }
    }
}
