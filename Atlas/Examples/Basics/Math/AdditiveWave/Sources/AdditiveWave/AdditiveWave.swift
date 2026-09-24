import Foundation
import mokume

/// Processing の [Additive Wave](https://processing.org/examples/additivewave/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。歪みが 2 つ重なる。**
/// 1. `frameRate(30)` — mokume は走り出す前 (`SketchSettings`) にしか決められない
/// 2. `colorMode(RGB, 255, 255, 255, 100)` — **色の範囲を変える口が無い。**
///    原典はこの 1 行で透かしの上限を 100 にしているので、続く `fill(255, 50)` の
///    50 は「半分」を意味する。mokume には `LinearRGBA` 1 種しか無いので、
///    範囲の変換を書く側が畳むことになり、**原典の 50 という数が消える**
///
/// 乱数で波の高さを決めるので、原典と mokume で数列が違う。**画素では比べられない。**
final class AdditiveWave: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Additive Wave")

    private let xspacing: Float = 8   // 横に置く間隔
    private var w: Float = 0          // 波ぜんぶの幅
    private let maxwaves = 4          // 足し合わせる波の数

    private var theta: Float = 0
    private var amplitude = [Float](repeating: 0, count: 4)
    private var dx = [Float](repeating: 0, count: 4)
    private var yvalues: [Float] = []

    func setup() {
        // 原典はここで `frameRate(30)` と `colorMode(RGB, 255, 255, 255, 100)` を呼ぶ。
        // 前者は settings へ移り、後者は**書けない**
        w = width + 16

        for i in 0..<maxwaves {
            amplitude[i] = random(10, 30)
            let period = random(100, 300)  // 何画素で 1 周するか
            dx[i] = ((.pi * 2) / period) * xspacing
        }

        yvalues = [Float](repeating: 0, count: Int(w / xspacing))
    }

    func draw() {
        background(0)
        calcWave()
        renderWave()
    }

    private func calcWave() {
        theta += 0.02

        for i in yvalues.indices { yvalues[i] = 0 }

        for j in 0..<maxwaves {
            var x = theta
            for i in yvalues.indices {
                // 1 つおきに cos を使う
                if j % 2 == 0 { yvalues[i] += sin(x) * amplitude[j] }
                else { yvalues[i] += cos(x) * amplitude[j] }
                x += dx[j]
            }
        }
    }

    private func renderWave() {
        noStroke()
        // 原典の `fill(255, 50)`。**透かしの上限が 100 になっている**ので、50 は半分
        fill(255, 255 * 50 / 100)
        ellipseMode(.center)
        for x in yvalues.indices {
            ellipse(Float(x) * xspacing, height / 2 + yvalues[x], 16, 16)
        }
    }
}
