// repro: mokume#1655
//
// 効果 (`effects([.invert()])`) を掛けた描き場所に、フレームの外で値を変えずに 1 画素
// 書き戻しても、次のフレームの効果は 1 回ぶんのはず (`effects` の説明「効果はどのフレームにも
// 1 回ぶんだけかかる」)。書き戻さない絵と、2 枚目を表示の 1 段 (1/255) より小さい差で比べる。
// 比べるのは、書き戻した右下の 1 画素から離れた左の 140 列である。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum EffectsOffFrameSet {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let written = try render(Scene(writesBack: true))
        let untouched = try render(Scene(writesBack: false))
        var differing = 0
        for y in 0..<untouched.height {
            for x in 0..<140 {
                let (p, q) = (written[x, y], untouched[x, y])
                let gap = max(abs(p.red - q.red), abs(p.green - q.green), abs(p.blue - q.blue), abs(p.alpha - q.alpha))
                if gap > 0.004 { differing += 1 }
            }
        }
        guard differing > 0 else { return nil }
        // (40, 80) は白い矩形を置いた左半分で、反転 1 回なら黒
        return "2 枚目で、書き戻した 1 画素から離れた所が \(differing) 画素違う"
            + " ((40, 80) の赤: 書き戻す \(written[40, 80].red) / 書き戻さない \(untouched[40, 80].red))"
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
        /// 1 枚目の後で、右下の 1 画素を値を変えずに書き戻すか。
        let writesBack: Bool
        var layer: Canvas!
        init(writesBack: Bool) { self.writesBack = writesBack }
        convenience init() { self.init(writesBack: false) }

        func setup() { layer = try! createGraphics(160, 160) }

        func draw() {
            layer.beginDraw()
            if frameCount == 1 {
                layer.background(0)
                layer.noStroke()
                layer.fill(255)
                layer.rect(0, 0, 80, 160)
            }
            layer.effects([.invert()])
            layer.endDraw()
            if frameCount == 1 && writesBack { layer.set(155, 155, layer.get(155, 155)) }
            background(0)
            image(layer, 0, 0)
        }
    }
}
