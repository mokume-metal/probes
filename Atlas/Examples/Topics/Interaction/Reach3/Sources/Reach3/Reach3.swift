import Foundation
import mokume

/// Processing の [Reach 3](https://processing.org/examples/reach3/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** 明るさ + 透かしの 2 つ組が書けない。
final class Reach3: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reach 3")

    private let numSegments = 8
    private var x: [Float] = []
    private var y: [Float] = []
    private var angle: [Float] = []
    private let segLength: Float = 26
    private var targetX: Float = 0
    private var targetY: Float = 0
    private var ballX: Float = 50
    private var ballY: Float = 50
    private var ballXDirection: Float = 1
    private var ballYDirection: Float = -1

    func setup() {
        x = [Float](repeating: 0, count: numSegments)
        y = [Float](repeating: 0, count: numSegments)
        angle = [Float](repeating: 0, count: numSegments)
        strokeWeight(20.0)
        stroke(255, 100)
        noFill()
        x[x.count - 1] = width / 2
        y[x.count - 1] = height
    }

    func draw() {
        background(0)

        strokeWeight(20)
        ballX = ballX + 1.0 * ballXDirection
        ballY = ballY + 0.8 * ballYDirection
        if ballX > width - 25 || ballX < 25 { ballXDirection *= -1 }
        if ballY > height - 25 || ballY < 25 { ballYDirection *= -1 }
        ellipse(ballX, ballY, 30, 30)

        reachSegment(0, ballX, ballY)
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
