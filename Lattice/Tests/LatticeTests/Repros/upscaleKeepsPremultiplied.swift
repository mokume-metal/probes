// repro: mokume#1638
//
// `pixelDensity` が 1 未満で描く面を出す面へ広げても、乗算済みの決まり (不透明度 ≤ 1・
// 色 ≤ 不透明度) は保たれるはず (mokume ADR-0011 決定 3・4、`mokume_enlarge` のコメント)。
// 下地を塗らない (透明のまま) 面に不透明な図形を描き、出す面の値を数える。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum UpscaleKeepsPremultiplied {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let runtime = try SketchRuntime(sketch: Scene(), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        let pixels = try runtime.target.readPixels()
        var (alphaOver, colorOver, largest) = (0, 0, Float(0))
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let c = pixels[x, y]
                if c.alpha > 1.001 { alphaOver += 1 }
                if Swift.max(c.red, c.green, c.blue) > c.alpha + 0.001 { colorOver += 1 }
                largest = Swift.max(largest, c.alpha)
            }
        }
        guard alphaOver > 0 || colorOver > 0 else { return nil }
        return "細かさ 0.5 の出す面で、不透明度 > 1 が \(alphaOver) 画素 (最大 \(largest))・"
            + "色 > 不透明度が \(colorOver) 画素"
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 100, height: 100, pixelDensity: 0.5)

        func draw() {
            // background() を呼ばない — 透明の下地
            noStroke()
            fill(255); circle(50, 50, 40)
            fill(255, 0, 0); rect(10, 10, 20, 20)
            fill(0); rect(30, 10, 20, 20)
        }
    }
}
