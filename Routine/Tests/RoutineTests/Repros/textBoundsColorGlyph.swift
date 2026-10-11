// repro: mokume#2308
//
// `textBounds` は「同じ引数で `text` を描いたときの墨を囲む」「墨が無いときは `nil` を返す」と
// 説明している。色を持つ字形 (絵文字) も `text` で描けば墨になるので、`"A🌲"` の枠は 🌲 の墨まで、
// `"🌲"` だけでも枠を返すはず。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum TextBoundsColorGlyph {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let scene = Scene()
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        let pixels = try runtime.target.readPixels()

        // 地 (黒) より明るい画素の右端 = "A🌲" の墨の右端
        var inkRight = -1
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let c = pixels[x, y]
                if max(c.red, c.green, c.blue) > 0.05 { inkRight = max(inkRight, x + 1) }
            }
        }
        var problems: [String] = []
        if scene.emojiOnly == nil {
            problems.append("textBounds(\"🌲\") が nil (text(\"🌲\") は墨を描く)")
        }
        if let mixed = scene.mixed {
            let right = mixed.x + mixed.width
            if right < Float(inkRight) - 1 {
                problems.append("textBounds(\"A🌲\") の右端が \(right) で、墨の右端 \(inkRight) に届かない")
            }
        } else {
            problems.append("textBounds(\"A🌲\") が nil")
        }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 120, frameRate: 30, title: "repro")
        var emojiOnly: TextBounds?
        var mixed: TextBounds?

        func draw() {
            background(0)
            fill(255)
            textSize(40)
            emojiOnly = textBounds("🌲", 20, 80)
            mixed = textBounds("A🌲", 20, 80)
            text("A🌲", 20, 80)
        }
    }
}
