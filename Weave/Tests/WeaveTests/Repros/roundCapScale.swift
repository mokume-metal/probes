// repro: mokume#1645
//
// `scale(20)` の下の太さ 1 の折れ線の丸い端は、同じ拡大の `line()` の丸い端と同じ形に
// なるはず (mokume ADR-0039 決定 1: 経路の違う同じ図形は、位置・大きさ・向きが一致する)。
// 縁の濃さは経路で違ってよいので、縁を 50% の被覆で白黒にした形で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum RoundCapScale {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let polyline = try render(Scene(usesLine: false))
        let line = try render(Scene(usesLine: true))
        var differing = 0
        for y in 0..<line.height {
            for x in 0..<line.width where (polyline[x, y].red >= 0.5) != (line[x, y].red >= 0.5) {
                differing += 1
            }
        }
        guard differing > 0 else { return nil }
        // (33, 33) は端の円 (中心 (40, 40)・半径 10) の中心から 9.2 で、円の内側
        return "縁を 50% で白黒にした形が \(differing) 画素違う"
            + " ((33, 33) の赤: 折れ線 \(polyline[33, 33].red) / line \(line[33, 33].red))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(_ scene: Scene) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        /// 折れ線の代わりに `line()` で描くか。
        let usesLine: Bool
        init(usesLine: Bool) { self.usesLine = usesLine }
        convenience init() { self.init(usesLine: false) }

        func draw() {
            background(0)
            noFill()
            stroke(255)
            scale(20, 20)
            strokeWeight(1)
            if usesLine {
                line(2, 2, 6, 2)
            } else {
                beginShape()
                vertex(2, 2)
                vertex(6, 2)
                endShape()
            }
        }
    }
}
