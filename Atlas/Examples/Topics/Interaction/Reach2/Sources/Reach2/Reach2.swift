import Foundation
import mokume

/// Processing の [Reach 2](https://processing.org/examples/reach2/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** 明るさ + 透かしの 2 つ組が書けない。
final class Reach2: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reach 2")

    private let numSegments = 10
    private var x: [Float] = []
    private var y: [Float] = []
    private var angle: [Float] = []
    private let segLength: Float = 26
    private var targetX: Float = 0
    private var targetY: Float = 0

    func setup() {
        x = [Float](repeating: 0, count: numSegments)
        y = [Float](repeating: 0, count: numSegments)
        angle = [Float](repeating: 0, count: numSegments)
        strokeWeight(20.0)
        stroke(255, 100)
        x[x.count - 1] = width / 2    // 根もとの x
        y[x.count - 1] = height       // 根もとの y
    }

    func draw() {
        background(0)

        reachSegment(0, mouseX, mouseY)
        for i in 1..<numSegments {
            reachSegment(i, targetX, targetY)
        }
        for i in stride(from: x.count - 1, through: 1, by: -1) {
            positionSegment(i, i - 1)
        }
        for i in 0..<x.count {
            segment(x[i], y[i], angle[i], Float(i + 1) * 2)
        }
    }

    private func positionSegment(_ a: Int, _ b: Int) {
        x[b] = x[a] + cos(angle[a]) * segLength
        y[b] = y[a] + sin(angle[a]) * segLength
    }

    private func reachSegment(_ i: Int, _ xin: Float, _ yin: Float) {
        let dx = xin - x[i]
        let dy = yin - y[i]
        angle[i] = atan2(dy, dx)
        targetX = xin - cos(angle[i]) * segLength
        targetY = yin - sin(angle[i]) * segLength
    }

    private func segment(_ x: Float, _ y: Float, _ a: Float, _ sw: Float) {
        strokeWeight(sw)
        pushMatrix()
        translate(x, y)
        rotate(a)
        line(0, 0, segLength, 0)
        popMatrix()
    }
}
