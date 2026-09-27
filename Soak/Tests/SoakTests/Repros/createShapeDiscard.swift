// repro: mokume#1588
//
// 同じフレームで先に図形を置いてから、`createShape { }` の中で `background()` を呼ぶと、戻るところで
// `Range requires lowerBound <= upperBound` でプロセスごと落ちる。`background` は描く口なので、
// 投げずに既定へ倒すはず (mokume ADR-0020 決定 5)。中で呼ばなければ通る。
//
// **落ちる事象なので、`reproduce()` の中で落ちる。** 戻ってくれば期待どおりで `nil` を返す。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import mokume

enum CreateShapeDiscardRepro {
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
            triangle(10, 10, 60, 10, 10, 60)  // 先に何か溜める
            _ = createShape { background(255) }
        }
    }
}
