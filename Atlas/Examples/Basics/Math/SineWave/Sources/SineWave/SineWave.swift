import Foundation
import mokume

/// Processing の [Sine Wave](https://processing.org/examples/sinewave/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `TWO_PI` は Swift の `Float.pi * 2` で当たる。
final class SineWave: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Sine Wave")

    private let xspacing: Float = 16   // 横に置く間隔
    private var w: Float = 0           // 波ぜんぶの幅

    private var theta: Float = 0.0     // 角度は 0 から
    private let amplitude: Float = 75.0 // 波の高さ
    private let period: Float = 500.0   // 何画素で 1 周するか
    private var dx: Float = 0
    private var yvalues: [Float] = []

    func setup() {
        w = width + 16
        dx = ((.pi * 2) / period) * xspacing
        yvalues = [Float](repeating: 0, count: Int(w / xspacing))
    }

    func draw() {
        background(0)
        calcWave()
        renderWave()
    }

    private func calcWave() {
        theta += 0.02

        var x = theta
        for i in yvalues.indices {
            yvalues[i] = sin(x) * amplitude
            x += dx
        }
    }

    private func renderWave() {
        noStroke()
        fill(255)
        for x in yvalues.indices {
            ellipse(Float(x) * xspacing, height / 2 + yvalues[x], 16, 16)
        }
    }
}
