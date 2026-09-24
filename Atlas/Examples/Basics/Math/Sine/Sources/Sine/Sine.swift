import Foundation
import mokume

/// Processing の [Sine](https://processing.org/examples/sine/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `PI` は Swift の `Float.pi` で当たる (台帳の `host`)。
final class Sine: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Sine")

    private var diameter: Float = 0
    private var angle: Float = 0

    func setup() {
        diameter = height - 10
        noStroke()
        fill(255, 204, 0)
    }

    func draw() {
        background(0)

        let d1 = 10 + (sin(angle) * diameter / 2) + diameter / 2
        let d2 = 10 + (sin(angle + .pi / 2) * diameter / 2) + diameter / 2
        let d3 = 10 + (sin(angle + .pi) * diameter / 2) + diameter / 2

        ellipse(0, height / 2, d1, d1)
        ellipse(width / 2, height / 2, d2, d2)
        ellipse(width, height / 2, d3, d3)

        angle += 0.02
    }
}
