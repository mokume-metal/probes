import Foundation
import mokume

/// Processing の [Follow 3](https://processing.org/examples/follow3/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** 明るさ + 透かしの 2 つ組が書けない。
final class Follow3: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Follow 3")

    private var x = [Float](repeating: 0, count: 20)
    private var y = [Float](repeating: 0, count: 20)
    private let segLength: Float = 18

    func setup() {
        strokeWeight(9)
        stroke(255, 100)
    }

    func draw() {
        background(0)
        dragSegment(0, mouseX, mouseY)
        for i in 0..<(x.count - 1) {
            dragSegment(i + 1, x[i], y[i])
        }
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
