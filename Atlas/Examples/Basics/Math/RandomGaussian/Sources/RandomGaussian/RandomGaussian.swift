import Foundation
import mokume

/// Processing の [Random Gaussian](https://processing.org/examples/randomgaussian/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `randomGaussian()` が無い。
/// mokume の `random` は一様な乱数だけなので、正規分布は面の外で作る。
/// **ここでは Box–Muller で組んでいる**ので、原典と数の作り方そのものが違う。
///
/// 乱数が主題なので **画素では比べられない。**
final class RandomGaussian: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Random Gaussian")

    func setup() {
        background(0)
    }

    func draw() {
        // 平均 0・標準偏差 1 の正規乱数。**mokume には無いので自分で組む**
        let val = randomGaussian()

        let sd: Float = 60                 // 標準偏差
        let mean = width / 2               // 平均 (面の横の真ん中)
        let x = (val * sd) + mean          // 標準偏差と平均で伸ばす

        noStroke()
        fill(255, 10)
        ellipse(x, height / 2, 32, 32)
    }

    /// 原典の `randomGaussian()`。一様な乱数 2 つから正規乱数を作る (Box–Muller)。
    private func randomGaussian() -> Float {
        let u1 = max(random(1), 1e-7)
        let u2 = random(1)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
