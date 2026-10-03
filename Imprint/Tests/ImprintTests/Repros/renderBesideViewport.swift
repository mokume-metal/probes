// repro: mokume#2025
//
// `mokume watch` が走っている場所 (`.mokume/viewport` が在る場所) で書き出しを起こすと、標準入力が
// 閉じている (/dev/null・CI・エージェント) だけで「道具が居なくなった」と読み、1 枚も書かずに
// 終了コード 1 で終わる。書き出しは窓を持たず、viewport が残っていても使わない約束である
// (mokume#1282 の完了条件 5)。viewport が無い場所なら、同じ頼みで 30 枚を書いて 0 で終わる。
//
// `mokume render` が子に渡すのと同じ `MOKUME_RENDER` を立てて `SketchApplication` を走らせる。
// **終わり方そのものが判定である。** `run()` は戻らず、書き切れば 0、途中で止まれば 1 で
// プロセスが終わる。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum RenderBesideViewport {
    /// 戻らない。書き切れば終了コード 0、書かずに止まれば 1 で終わる。
    static func reproduce() throws -> String? {
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("render-beside-viewport-\(getpid())")
        // watch が置く区画。中身は空でよい — 在るかどうかだけで決まる
        try FileManager.default.createDirectory(
            at: place.appendingPathComponent(".mokume/viewport"), withIntermediateDirectories: true)
        let out = place.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        setenv("MOKUME_WORK_DIR", place.path, 1)
        setenv("MOKUME_RENDER", "30:30:\(out.path)/f-####.png", 1)
        // 端末の無い書き出し (CI・エージェント・cron) と同じく、標準入力は閉じている
        let null = open("/dev/null", O_RDONLY)
        dup2(null, STDIN_FILENO)
        try SketchApplication(sketch: Scene(), gpu: RenderDevice()).run()
        return nil
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 64, height: 64, frameRate: 30, title: "repro")

        func draw() {
            background(0)
            circle(Float(frameCount), 32, 16)
        }
    }
}
