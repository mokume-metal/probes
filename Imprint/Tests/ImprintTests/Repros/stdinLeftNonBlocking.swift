// repro: mokume#2024
//
// `.mokume/viewport` が在る場所 (`mokume watch` が走っている場所) で `SketchRuntime` を作ると、
// 道具に起こされたと読んで標準入力に `O_NONBLOCK` を立て、戻さない。標準入力が端末なら、この
// フラグは端末を共有する親のシェルにも残る。終わった後で同じ端末から標準入力を読むプログラムが
// `EAGAIN` (Errno 35) で落ちる。窓を持たない `SketchRuntime` (検査・書き出し) は道具の管を
// 持たないので、標準入力に触らないはずである。viewport が無い場所なら、フラグは立たない。
//
// ここでは標準入力を管に差し替え、`SketchRuntime` を作って 1 枚進めた前後でフラグを比べる。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum StdinLeftNonBlocking {
    /// 標準入力のフラグが変わらなければ `nil` を返す。
    static func reproduce() throws -> String? {
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("stdin-left-nonblocking-\(getpid())")
        try FileManager.default.createDirectory(
            at: place.appendingPathComponent(".mokume/viewport"), withIntermediateDirectories: true)
        // `WorkDirectory.base` は初めて読まれたときにこれを引く
        setenv("MOKUME_WORK_DIR", place.path, 1)
        var pipeEnds: [Int32] = [0, 0]
        pipe(&pipeEnds)
        dup2(pipeEnds[0], STDIN_FILENO)

        let before = fcntl(STDIN_FILENO, F_GETFL) & O_NONBLOCK != 0
        let runtime = try SketchRuntime(sketch: Scene(), gpu: RenderDevice())
        try runtime.advance()
        runtime.closePlugins()
        let after = fcntl(STDIN_FILENO, F_GETFL) & O_NONBLOCK != 0
        guard before != after else { return nil }
        return "標準入力の O_NONBLOCK: SketchRuntime の前 \(before) → 後 \(after)"
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 64, height: 64, frameRate: 30, title: "repro")

        func draw() { background(0) }
    }
}
