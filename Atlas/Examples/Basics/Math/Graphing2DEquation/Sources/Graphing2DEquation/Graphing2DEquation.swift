import Foundation
import mokume

/// Processing の [Graphing 2D Equation](https://processing.org/examples/graphing2dequation/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `updatePixels()` の口が無い。
/// ただし止まるのは合図だけで、`pixels` への書き込みそのものは届く。
///
/// **画素の並びの形が違う。** 原典は 1 次元の並び (`pixels[i + j*width]`) で、
/// mokume の `Pixels` は 2 次元の添字 (`pixels[i, j]`) を取る。行と列の掛け算が
/// 消えるので原典より読みやすいが、**同じ書き方ではない**。
final class Graphing2DEquation: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Graphing 2D Equation")

    func draw() {
        loadPixels()
        let n = (mouseX * 10.0) / width
        let w: Float = 16.0        // 2 次元の面の幅
        let h: Float = 16.0        // 2 次元の面の高さ
        let dx = w / width         // 1 画素あたり x をこれだけ進める
        let dy = h / height        // 1 画素あたり y をこれだけ進める
        var x = -w / 2             // x は -幅/2 から
        for i in 0..<Int(width) {
            var y = -h / 2         // y は -高さ/2 から
            for j in 0..<Int(height) {
                let r = ((x * x) + (y * y)).squareRoot()   // 直交座標から極座標へ
                let theta = atan2(y, x)                    // 直交座標から極座標へ
                // 極座標の式。-1 から 1 の間の値になる
                let val = sin(n * cos(r) + 5 * theta)
                // 出た値を灰色の値へ移す (0 から 255 の間へ)
                pixels[i, j] = color((val + 1.0) * 255.0 / 2.0)
                y += dy
            }
            x += dx
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない** — 書き戻しの合図が無い
    }
}
