// repro: mokume#1587
//
// 有限だが巨大な `textSize` (1e20) で字を 1 つ描くと、プロセスごと落ちる (SIGTRAP。lldb で止めると
// `Double value cannot be converted to Int because the result would be greater than Int.max`)。
// `text` は描く口なので、投げずに何も置かないはず (mokume ADR-0020 決定 5)。`textSize(1e19)` なら
// 「大きすぎる」と注意して何も置かずに通る。
//
// **落ちる事象なので、`reproduce()` の中で落ちる。** 戻ってくれば期待どおりで `nil` を返す。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import mokume

enum HugeTextSizeRepro {
    /// 落ちなければ `nil` を返す。
    static func reproduce() throws -> String? {
        let runtime = try SketchRuntime(sketch: Scene(), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return nil
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")

        func draw() {
            textSize(1e20)
            text("M", 10, 100)
        }
    }
}
