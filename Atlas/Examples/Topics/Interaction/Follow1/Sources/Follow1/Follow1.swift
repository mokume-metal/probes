import Foundation
import mokume

/// Processing の [Follow 1](https://processing.org/examples/follow1/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `stroke(255, 100)` の**明るさ + 透かしの
/// 2 つ組**が書けない。それ以外は原典と同じ行が並ぶ。
final class Follow1: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Follow 1")

    private var x: Float = 100
    private var y: Float = 100
    private var angle1: Float = 0.0
    private let segLength: Float = 50

    func setup() {
        strokeWeight(20.0)
        stroke(255, 100)
    }

    func draw() {
        background(0)

        let dx = mouseX - x
        let dy = mouseY - y
        angle1 = atan2(dy, dx)
        x = mouseX - (cos(angle1) * segLength)
        y = mouseY - (sin(angle1) * segLength)

        segment(x, y, angle1)
        ellipse(x, y, 20, 20)
    }

    private func segment(_ x: Float, _ y: Float, _ a: Float) {
        pushMatrix()
        translate(x, y)
        rotate(a)
        line(0, 0, segLength, 0)
        popMatrix()
    }
}
