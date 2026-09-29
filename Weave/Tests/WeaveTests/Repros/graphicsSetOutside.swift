// repro: mokume#1654
//
// `beginDraw()` / `endDraw()` の外で描き場所へ `set()` した画素は、断られるはず (mokume ADR-0021
// 決定 4 の追補 (2026-09-27)「置いたものと書いた画素をフレームの外に置いてよいのは、持ち越しを
// 約束する区間だけ」。描き場所ではその区間が `beginDraw()`〜`endDraw()`)。断られたなら、読む口の
// `get` と `image` はどちらも、書かなかった絵を見る。外で書かなかった絵と、表示の 1 段 (1/255) より
// 小さい差で比べる。囲んで書いた右半分の青は、どちらにも出る (対照)。
//
// 起票した `v0.12.0` では、外で書いた赤を `get` だけが返し、`image` には出なかった (読む口どうしの
// 食い違い)。当時の期待は「`image` にも出る」だったが、mokume#1681 が「断る」ほうに約束を決めて
// #1654 を閉じたので、期待をそちらへ替えた。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum GraphicsSetOutside {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let outside = Scene(writesOutside: true)
        let untouched = Scene(writesOutside: false)
        let bare = try render(outside)
        let reference = try render(untouched)
        let differing = count(bare, reference)
        // (40, 80) は外で赤を書いた左半分の中
        let (read, expected) = (outside.layer.get(40, 80), untouched.layer.get(40, 80))
        let readGap = max(
            abs(read.red - expected.red), abs(read.green - expected.green), abs(read.blue - expected.blue),
            abs(read.alpha - expected.alpha))
        guard differing > 0 || readGap > 0.004 else { return nil }
        return "外で書いた画素が断られていない: image は書かなかった絵と \(differing) 画素違う"
            + " ((40, 80) の赤: image \(bare[40, 80].red) / get \(read.red)"
            + " / 書かなかったときの image \(reference[40, 80].red) / get \(expected.red))"
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
        /// 囲んだ後で、左半分へ `beginDraw()` / `endDraw()` の外から書くか。
        let writesOutside: Bool
        var layer: Canvas!
        init(writesOutside: Bool) { self.writesOutside = writesOutside }
        convenience init() { self.init(writesOutside: true) }

        func setup() {
            layer = try! createGraphics(160, 160)
            layer.beginDraw()
            for y in 0..<160 {
                for x in 80..<160 { layer.set(x, y, color(0, 0, 255)) }
            }
            layer.endDraw()
            guard writesOutside else { return }
            for y in 0..<160 {
                for x in 0..<80 { layer.set(x, y, color(255, 0, 0)) }
            }
        }

        func draw() {
            background(0)
            image(layer, 0, 0)
        }
    }
}
