// repro: mokume#1637
//
// `pixelDensity` 0.5 でも、太さ 1 の輪郭は置く位置によらず、細かさ 1 と同じくらいの光の量で
// 出るはず (`SketchSettings.pixelDensity` の説明:「置く位置によらずその太さぶんの濃さで」)。
// 三角形の経路 (`quad`) の輪郭を、上辺 y = 10 と 11 に置いて、出す面の赤の総和を比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ThinOutline {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let reference = try light(y: 10, density: 1)
        var found: [String] = []
        for y: Float in [10, 11] {
            let low = try light(y: y, density: 0.5)
            // 拡大段が総光量を少し増やすので、許容は ±20%
            if Swift.abs(low - reference) >= reference * 0.2 { found.append("y = \(Int(y)) で \(low)") }
        }
        guard !found.isEmpty else { return nil }
        return "細かさ 0.5 の quad の輪郭の光の量が " + found.joined(separator: "・")
            + " (細かさ 1 の y = 10 は \(reference))"
    }

    /// 軸に沿った `quad` の太さ 1 の輪郭を 1 枚描き、出す面の赤の総和を返す。
    static func light(y: Float, density: Float) throws -> Float {
        let sketch = Scene(SketchSettings(width: 100, height: 100, pixelDensity: density)) { s in
            s.quad(10, y, 90, y, 90, y + 60, 10, y + 60)
        }
        let runtime = try SketchRuntime(sketch: sketch, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        let pixels = try runtime.target.readPixels()
        var sum: Float = 0
        for y in 0..<pixels.height {
            for x in 0..<pixels.width { sum += pixels[x, y].red }
        }
        return sum
    }

    final class Scene: Sketch {
        var settings: SketchSettings
        let shape: (Scene) -> Void
        init(_ settings: SketchSettings, _ shape: @escaping (Scene) -> Void) {
            self.settings = settings
            self.shape = shape
        }
        convenience init() { self.init(SketchSettings()) { _ in } }

        func draw() {
            background(0)
            noFill()
            stroke(255)
            strokeWeight(1)
            shape(self)
        }
    }
}
