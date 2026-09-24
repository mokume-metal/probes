import Foundation
import mokume

/// Processing の [Follow 2](https://processing.org/examples/follow2/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** 明るさ + 透かしの 2 つ組が書けない。
final class Follow2: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Follow 2")

    private var x = [Float](repeating: 0, count: 2)
    private var y = [Float](repeating: 0, count: 2)
    private let segLength: Float = 50

    func setup() {
        strokeWeight(20.0)
        stroke(255, 100)
    }

    func draw() {
        background(0)
        dragSegment(0, mouseX, mouseY)
        dragSegment(1, x[0], y[0])
    }

    private func dragSegment(_ i: Int, _ xin: Float, _ yin: Float) {
        let dx = xin - x[i]
        let dy = yin - y[i]
        let angle = atan2(dy, dx)
        x[i] = xin - cos(angle) * segLength
        y[i] = yin - sin(angle) * segLength
        segment(x[i], y[i], angle)
    }

    private func segment(_ x: Float, _ y: Float, _ a: Float) {
        pushMatrix()
        translate(x, y)
        rotate(a)
        line(0, 0, segLength, 0)
        popMatrix()
    }
}
