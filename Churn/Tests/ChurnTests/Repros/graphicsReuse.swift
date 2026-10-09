// repro: mokume#未起票
//
// 描き場所を置いてから同じフレームで描き換えても、先に置いた所には置いた時点の絵が出るはず
// (`createGraphics` の説明「描き換えても、置いた時点の絵が出る」)。
//
// 同じフレームの中で、置いた描き場所 `dying` を捨て、次に作った描き場所 `born` が同じ `ObjectIdentifier` を
// 引き継ぐ (解放したアドレスの使い回し) と、`born` を緑で置いてから青へ描き換えた所が青になる。
// `dying` を生かしたまま同じことをする対照は緑になる。
//
// 引き継ぎはアドレスの使い回しに頼るので、`born` を作り直して `ObjectIdentifier` が一致した回だけを比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum GraphicsReuse {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let reused = try render(keepAlive: false)
        let kept = try render(keepAlive: true)
        guard reused.matched else { return "ObjectIdentifier の引き継ぎが起きず、確かめられなかった" }
        // (80, 80) は緑で置いた所。置いた時点の絵 (緑) が出るはず
        let a = reused.pixels[80, 80]
        let b = kept.pixels[80, 80]
        guard a.blue > 0.5 else { return nil }
        return "引き継いだ描き場所を置いた所が青 (赤・緑・青 \(a.red)・\(a.green)・\(a.blue))。"
            + "前の描き場所を生かした対照は \(b.red)・\(b.green)・\(b.blue)"
    }

    /// 窓を出さずに 1 枚描いて、画素と、引き継ぎが起きたかを返す。
    static func render(keepAlive: Bool) throws -> (pixels: PixelBuffer, matched: Bool) {
        let scene = Scene(keepAlive: keepAlive)
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return (try runtime.target.readPixels(), scene.matched)
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")
        let keepAlive: Bool
        var matched = false
        init(keepAlive: Bool) { self.keepAlive = keepAlive }
        convenience init() { self.init(keepAlive: false) }

        func draw() {
            background(0)
            var dying: Canvas? = try! createGraphics(40, 40)
            dying!.beginDraw()
            dying!.background(255, 0, 0)
            dying!.endDraw()
            image(dying!, 10, 10)
            let gone = ObjectIdentifier(dying!)
            let kept = keepAlive ? dying : nil
            dying = nil

            var born = try! createGraphics(40, 40)
            var held: [Canvas] = []
            while !keepAlive, ObjectIdentifier(born) != gone, held.count < 256 {
                held.append(born)
                born = try! createGraphics(40, 40)
            }
            matched = ObjectIdentifier(born) == gone
            born.beginDraw()
            born.background(0, 255, 0)
            born.endDraw()
            image(born, 60, 60)
            born.beginDraw()
            born.background(0, 0, 255)
            born.endDraw()
            withExtendedLifetime(kept) {}
        }
    }
}
