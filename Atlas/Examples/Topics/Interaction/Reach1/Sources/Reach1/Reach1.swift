import Foundation
import mokume

/// Processing の [Reach 1](https://processing.org/examples/reach1/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** 明るさ + 透かしの 2 つ組が書けない。
final class Reach1: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reach 1")

    private let segLength: Float = 80
    private var x: Float = 0
    private var y: Float = 0
    private var x2: Float = 0
    private var y2: Float = 0

    func setup() {
        strokeWeight(20.0)
        stroke(255, 100)

        x = width / 2
        y = height / 2
        x2 = x
        y2 = y
    }

    func draw() {
        background(0)

        var dx = mouseX - x
        var dy = mouseY - y
        let angle1 = atan2(dy, dx)

        let tx = mouseX - cos(angle1) * segLength
        let ty = mouseY - sin(angle1) * segLength
        dx = tx - x2
        dy = ty - y2
        let angle2 = atan2(dy, dx)
        x = x2 + cos(angle2) * segLength
        y = y2 + sin(angle2) * segLength

        segment(x, y, angle1)
        segment(x2, y2, angle2)
    }

    private func segment(_ x: Float, _ y: Float, _ a: Float) {
        pushMatrix()
        translate(x, y)
        rotate(a)
        line(0, 0, segLength, 0)
        popMatrix()
    }
}
