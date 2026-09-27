// repro: mokume#1639
//
// 利用者の効果が受け取る `Pixel.position` は、座標や線の太さと同じ出す画素のはず
// (`Sketch.effects(_:)` の説明:「画素は座標や線の太さと同じ出す画素で、`pixelDensity` を
// 下げてもぼけ・にじみの幅は変わらない」)。`floor(in.position / 8)` の市松を細かさ 1 と
// 0.5 で掛け、出す面を 50% で白黒にして比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum EffectPositionIsOutputPixels {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let full = try render(density: 1)
        let low = try render(density: 0.5)
        var differing = 0
        for y in 0..<full.height {
            for x in 0..<full.width where (full[x, y].red > 0.5) != (low[x, y].red > 0.5) {
                differing += 1
            }
        }
        guard differing > 0 else { return nil }
        return "64×64 のうち \(differing) 画素で白黒が違う"
            + " (2 行目: 細かさ 1 は \(row(full, 1)) / 細かさ 0.5 は \(row(low, 1)))"
    }

    /// 行 `y` の先頭 40 画素を、白 `#`・黒 `.` で書く。
    static func row(_ pixels: PixelBuffer, _ y: Int) -> String {
        String((0..<40).map { pixels[$0, y].red > 0.5 ? "#" : "." })
    }

    static func render(density: Float) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Scene(density: density), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings: SketchSettings
        var checker: EffectShader?
        init(density: Float) {
            settings = SketchSettings(width: 64, height: 64, pixelDensity: density)
        }
        convenience init() { self.init(density: 1) }

        func setup() {
            checker = try? makeEffect(
                """
                float4 effect(Pixel in, Values values) {
                    float2 cell = floor(in.position / 8.0);   // 8 画素の市松
                    return fmod(cell.x + cell.y, 2.0) < 0.5 ? float4(1, 1, 1, 1) : float4(0, 0, 0, 1);
                }
                """)
        }

        func draw() {
            background(0)
            if let checker { effects([.custom(checker)]) }
        }
    }
}
