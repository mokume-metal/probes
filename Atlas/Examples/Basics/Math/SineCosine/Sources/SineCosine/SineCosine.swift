import Foundation
import mokume

/// Processing の [Sine Cosine](https://processing.org/examples/sinecosine/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `radians()` が無いので面の外に書く
/// ([#883](https://github.com/mokume-metal/mokume/issues/883))。23 本の例がこれを要求する。
final class SineCosine: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Sine Cosine")

    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0
    private var angle1: Float = 0
    private var angle2: Float = 0
    private let scalar: Float = 70

    func setup() {
        noStroke()
        rectMode(.center)
    }

    func draw() {
        background(0)

        let ang1 = radians(angle1)
        let ang2 = radians(angle2)

        x1 = width / 2 + (scalar * cos(ang1))
        x2 = width / 2 + (scalar * cos(ang2))

        y1 = height / 2 + (scalar * sin(ang1))
        y2 = height / 2 + (scalar * sin(ang2))

        fill(255)
        rect(width * 0.5, height * 0.5, 140, 140)

        fill(0, 102, 153)
        ellipse(x1, height * 0.5 - 120, scalar, scalar)
        ellipse(x2, height * 0.5 + 120, scalar, scalar)

        fill(255, 204, 0)
        ellipse(width * 0.5 - 120, y1, scalar, scalar)
        ellipse(width * 0.5 + 120, y2, scalar, scalar)

        angle1 += 2
        angle2 += 3
    }
}
