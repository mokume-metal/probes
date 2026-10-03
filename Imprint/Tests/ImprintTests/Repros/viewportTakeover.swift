// repro: mokume#未起票
//
// `mokume watch A` が走っている場所で、道具に起こされていないスケッチ B を走らせる (`swift run`・
// 別の実行ファイル・2 本目の道具)。B は自分の窓を開かず、watch の目録 `.mokume/viewport/surface.json`
// を自分の面で上書きする。watch の作品の窓とプレビューは B の絵を映し、B が終わった後も B の
// 最後の 1 枚で止まる。A の子は裏で描き続けているのに、A を保存し直すまで戻らない。
//
// 窓を出すか共有面へ差し出すかは「区画が在るか」だけで決まり、区画に錠が無い。起こした道具を
// 確かめていない (`StartupReads.viewport` は `decidedBy: .tool` と名乗っている)。道具が無くても
// 作品はそれ自体で動く (mokume ADR-0032 の不変条件) はずである。
//
// ここでは watch A が書いた目録を装って置き、B を走らせて 10 枚目で目録を読む。**終わり方が
// 判定である。** 目録がそのままなら 0、書き換わっていれば 1 でプロセスが終わる。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum ViewportTakeover {
    /// watch A が置いた目録 (A の面の番号)。
    static let watched = #"{"height":120,"ids":[1,2,3,4],"schemaVersion":1,"width":160}"#
    nonisolated(unsafe) static var listing = URL(fileURLWithPath: "/")

    /// 戻らない。目録がそのままなら終了コード 0、書き換わっていれば 1 で終わる。
    static func reproduce() throws -> String? {
        let place = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewport-takeover-\(getpid())")
        let viewport = place.appendingPathComponent(".mokume/viewport")
        try FileManager.default.createDirectory(at: viewport, withIntermediateDirectories: true)
        listing = viewport.appendingPathComponent("surface.json")
        try Data(watched.utf8).write(to: listing)
        setenv("MOKUME_WORK_DIR", place.path, 1)
        // 端末から起こしたのと同じく、標準入力は開いたまま何も来ない
        var pipeEnds: [Int32] = [0, 0]
        pipe(&pipeEnds)
        dup2(pipeEnds[0], STDIN_FILENO)
        try SketchApplication(sketch: Scene(), gpu: RenderDevice()).run()
        return nil
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 300, height: 200, frameRate: 30, title: "repro B")

        func draw() {
            background(20, 40, 220)
            guard frameCount == 10 else { return }
            let now = (try? String(contentsOf: ViewportTakeover.listing, encoding: .utf8)) ?? "(読めない)"
            if now == ViewportTakeover.watched { exit(0) }
            FileHandle.standardError.write(
                Data("watch A の目録が B の面に書き換わった: \(now.filter { !$0.isWhitespace })\n".utf8))
            exit(1)
        }
    }
}
