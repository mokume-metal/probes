import Foundation
import mokume

/// Processing の [Star](https://processing.org/examples/star/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
final class Star: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Star")

    func draw() {
        background(102)

        pushMatrix()
        translate(width * 0.2, height * 0.5)
        rotate(Float(frameCount) / 200.0)
        star(0, 0, 5, 70, 3)
        popMatrix()

        pushMatrix()
        translate(width * 0.5, height * 0.5)
        rotate(Float(frameCount) / 400.0)
        star(0, 0, 80, 100, 40)
        popMatrix()

        pushMatrix()
        translate(width * 0.8, height * 0.5)
        rotate(Float(frameCount) / -100.0)
        star(0, 0, 30, 70, 5)
        popMatrix()
    }

    private func star(_ x: Float, _ y: Float, _ radius1: Float, _ radius2: Float, _ npoints: Int) {
        let angle = (.pi * 2) / Float(npoints)
        let halfAngle = angle / 2.0
        beginShape()
        for a in stride(from: Float(0), to: .pi * 2, by: angle) {
            vertex(x + cos(a) * radius2, y + sin(a) * radius2)
            vertex(x + cos(a + halfAngle) * radius1, y + sin(a + halfAngle) * radius1)
        }
        endShape(.close)
    }
}
