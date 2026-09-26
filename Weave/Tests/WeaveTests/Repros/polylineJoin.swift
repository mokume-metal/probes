// repro: mokume#1644
//
// 一直線に並べた 3 点の太い折れ線は、同じ 2 点を結ぶ `line()` と同じ形になるはず
// (mokume ADR-0039 決定 1: 経路の違う同じ図形は、位置・大きさ・向きが一致する)。
// 縁の濃さは経路で違ってよいので、縁を 50% の被覆で白黒にした形で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum PolylineJoin {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let polyline = try render { s in
            s.beginShape()
            s.vertex(20, 20)
            s.vertex(80, 80)
            s.vertex(140, 140)
            s.endShape()
        }
        let line = try render { s in s.line(20, 20, 140, 140) }
        var differing = 0
        for y in 0..<line.height {
            for x in 0..<line.width where (polyline[x, y].red >= 0.5) != (line[x, y].red >= 0.5) {
                differing += 1
            }
        }
        guard differing > 0 else { return nil }
        // (88, 72) は直線から 11.3 離れ、太さ 20 の帯 (半分 10) の外
        return "縁を 50% で白黒にした形が \(differing) 画素違う"
            + " ((88, 72) の赤: 折れ線 \(polyline[88, 72].red) / line \(line[88, 72].red))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(_ shape: @escaping (Scene) -> Void) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Scene(shape), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        let shape: (Scene) -> Void
        init(_ shape: @escaping (Scene) -> Void) { self.shape = shape }
        convenience init() { self.init { _ in } }

        func draw() {
            background(0)
            noFill()
            stroke(255)
            strokeWeight(20)
            shape(self)
        }
    }
}
