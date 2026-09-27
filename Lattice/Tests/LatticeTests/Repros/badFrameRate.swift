// repro: mokume#1642
//
// `frameRate` も組み立てで読む設定なので、`pixelDensity` の範囲外と同じく、0 や負の値は
// 組み立てで断るはず (mokume ADR-0020 決定 5: 資源の生成・初期化は型のついたエラーを投げる)。
// `frameRate: 0` でランタイムを組み、投げるかと 2 枚目の `time` を見る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum BadFrameRate {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let runtime: SketchRuntime
        do {
            runtime = try SketchRuntime(sketch: Scene(), gpu: RenderDevice())
        } catch {
            return nil
        }
        defer { runtime.closePlugins() }
        try runtime.advance()
        try runtime.advance()
        return "frameRate 0 で組み立てが投げず、2 枚目の time は \(runtime.time)・deltaTime は \(runtime.deltaTime)"
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 10, height: 10, frameRate: 0)
        func draw() {}
    }
}
