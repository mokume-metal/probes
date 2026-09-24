import Foundation
import mokume

/// Processing の [Koch](https://processing.org/examples/koch/) を 1 行ずつ移したもの。
/// 原典は 3 つのタブ (`Koch` / `KochFractal` / `KochLine`) に分かれている。
///
/// **台帳は `bend` と言った。当たっている。歪みが 2 つ。**
/// `frameRate(1)` は走り出す前にしか決められず、`PVector` の
/// `sub` / `div` / `add` / `copy` / `rotate` に当たるものが無い。
/// **とくに `rotate` が痛い** — 原典はベクトル自身に「60 度回れ」と頼むが、
/// こちらは回転の式を書き下すことになる。
final class Koch: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 1, title: "Koch")

    /// 原典の `class KochLine`。左端の a と右端の b を持つ。
    struct KochLine {
        let a: SIMD2<Float>
        let b: SIMD2<Float>

        func display(on sketch: any Sketch) {
            sketch.stroke(255)
            sketch.line(a.x, a.y, b.x, b.y)
        }

        /// 3 分の 1 のところ
        var kochleft: SIMD2<Float> { (b - a) / 3 + a }

        /// 真ん中の山。**原典は `v.rotate(-radians(60))` の 1 行**
        var kochmiddle: SIMD2<Float> {
            let v = (b - a) / 3
            let angle = -radians(60)
            let turned = SIMD2<Float>(v.x * cos(angle) - v.y * sin(angle),
                                      v.x * sin(angle) + v.y * cos(angle))
            return a + v + turned
        }

        /// 3 分の 2 のところ
        var kochright: SIMD2<Float> { (a - b) / 3 + b }
    }

    /// 原典の `class KochFractal`。
    final class KochFractal {
        let start: SIMD2<Float>
        let end: SIMD2<Float>
        var lines: [KochLine] = []
        var count = 0

        init(width: Float, height: Float) {
            start = SIMD2(0, height - 20)
            end = SIMD2(width, height - 20)
            restart()
        }

        func nextLevel() {
            lines = iterate(lines)
            count += 1
        }

        func restart() {
            count = 0
            lines = [KochLine(a: start, b: end)]
        }

        func render(on sketch: any Sketch) {
            for l in lines { l.display(on: sketch) }
        }

        /// 1 本を 4 本へ割る
        private func iterate(_ before: [KochLine]) -> [KochLine] {
            var now: [KochLine] = []
            for l in before {
                let a = l.a, b = l.kochleft, c = l.kochmiddle, d = l.kochright, e = l.b
                now.append(KochLine(a: a, b: b))
                now.append(KochLine(a: b, b: c))
                now.append(KochLine(a: c, b: d))
                now.append(KochLine(a: d, b: e))
            }
            return now
        }
    }

    private var k: KochFractal?

    func setup() {
        // 原典はここで `frameRate(1)` を呼ぶ。settings へ移した
        k = KochFractal(width: width, height: height)
    }

    func draw() {
        background(0)
        k?.render(on: self)
        k?.nextLevel()
        // 5 回より多くはしない
        if let k, k.count > 5 { k.restart() }
    }
}
