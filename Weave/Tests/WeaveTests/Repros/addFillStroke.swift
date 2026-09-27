// repro: mokume#1643
//
// `blendMode(.add)` で塗りと輪郭を両方持つ図形を 1 回で描いた絵は、塗りだけの図形の上に
// 輪郭だけの図形を重ねた絵と同じになるはず (距離関数の経路の `mokume_formFragment` は
// 「三角形を重ねたのと同じ式」を名乗る)。同じ機械なら同じ絵が出る (mokume ADR-0001
// 原則 2) ので、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum AddFillStroke {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let once = try render(Scene(split: false))
        let split = try render(Scene(split: true))
        let differing = count(once, split)
        guard differing > 0 else { return nil }
        // (26, 52) は矩形の左辺の輪郭の帯 (太さ 12) の内側半分
        return "1 回で描いた絵と、塗りと輪郭を分けて重ねた絵が \(differing) 画素違う"
            + " ((26, 52) の青: 1 回 \(once[26, 52].blue) / 分けて \(split[26, 52].blue))"
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
        /// 塗りだけの図形と輪郭だけの図形に分けて重ねるか。
        let split: Bool
        init(split: Bool) { self.split = split }
        convenience init() { self.init(split: false) }

        func draw() {
            background(0)
            blendMode(.add)
            if split {
                shapes(filled: true, stroked: false)
                shapes(filled: false, stroked: true)
            } else {
                shapes(filled: true, stroked: true)
            }
        }

        /// 青い塗りと赤い輪郭 (太さ 12) の矩形と円。
        func shapes(filled: Bool, stroked: Bool) {
            if filled { fill(0, 0, 160) } else { noFill() }
            if stroked { stroke(160, 0, 0) } else { noStroke() }
            strokeWeight(12)
            rect(24, 24, 56, 56)
            circle(112, 112, 56)
        }
    }
}
