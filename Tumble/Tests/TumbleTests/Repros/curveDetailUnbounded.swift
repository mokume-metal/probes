// repro: mokume#未起票
//
// `curveDetail` に上限が無く、大きな値の後の `bezierVertex` は、渡した数だけ点を作る。`curveDetail(Int.max)` の
// 後に `bezierVertex` を 1 つ呼ぶとフレームが戻らず、確保が増え続ける (130 秒で 21 GB)。立体の分け方
// (`sphere(_:detail:)` など) は「手が滑って大きな値を渡しても確保が跳ね上がらないよう」上限 128 へ丸める
// (mokume `SolidShape.detailRange`・ADR-0020 決定 5: 描画は投げずに範囲へ丸める)。曲線の刻みも、ある値から
// 先は点の数が増えないはず。
//
// 点の数は、保持した形 (`createShape`) の頂点の数で数える。時間で測らないので、機械によらず同じ数が出る。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum CurveDetailUnboundedRepro {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let scene = Scene()
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        let (curve10k, curve100k) = (scene.curves[0], scene.curves[1])
        let (sphere10k, sphere100k) = (scene.spheres[0], scene.spheres[1])
        guard curve100k > curve10k else { return nil }
        return "曲線 1 本の頂点: curveDetail(10000) で \(curve10k)・curveDetail(100000) で \(curve100k)"
            + " (立体は detail 10000 で \(sphere10k)・100000 で \(sphere100k))"
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 120, frameRate: 30, title: "repro")
        var curves: [Int] = []
        var spheres: [Int] = []

        func draw() {
            background(0)
            for detail in [10_000, 100_000] {
                let curve = createShape {
                    curveDetail(detail)
                    noFill()
                    stroke(255)
                    beginShape()
                    vertex(10, 100)
                    bezierVertex(40, 10, 120, 10, 150, 100)
                    endShape()
                }
                curves.append(curve.vertexCount)
                let ball = createShape { sphere(40, detail: detail) }
                spheres.append(ball.vertexCount)
            }
            curveDetail(20)
        }
    }
}
