import Foundation
import mokume
import Support

/// Processing の [Rollover](https://processing.org/examples/rollover/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `sq()` が無いので面の外に書く。
/// 触れているかどうかしか見ないので、**この例は出来事の口が要らない** — GUI の 4 本の
/// うち、丸ごと移せるのはこれだけである。
final class Rollover: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Rollover")

    private var rectX: Float = 0
    private var rectY: Float = 0
    private var circleX: Float = 0
    private var circleY: Float = 0
    private let rectSize: Float = 90
    private let circleSize: Float = 93
    private var rectColor = LinearRGBA.transparent
    private var circleColor = LinearRGBA.transparent
    private var baseColor = LinearRGBA.transparent
    private var rectOver = false
    private var circleOver = false

    func setup() {
        rectColor = color(0)
        circleColor = color(255)
        baseColor = color(102)
        circleX = width / 2 + circleSize / 2 + 10
        circleY = height / 2
        rectX = width / 2 - rectSize - 10
        rectY = height / 2 - rectSize / 2
        ellipseMode(.center)
    }

    func draw() {
        update()
        noStroke()
        if rectOver {
            background(rectColor)
        } else if circleOver {
            background(circleColor)
        } else {
            background(baseColor)
        }
        stroke(255)
        fill(rectColor)
        rect(rectX, rectY, rectSize, rectSize)
        stroke(0)
        fill(circleColor)
        ellipse(circleX, circleY, circleSize, circleSize)
    }

    private func update() {
        if overCircle(circleX, circleY, circleSize) {
            circleOver = true
            rectOver = false
        } else if overRect(rectX, rectY, rectSize, rectSize) {
            rectOver = true
            circleOver = false
        } else {
            circleOver = false
            rectOver = false
        }
    }

    private func overRect(_ x: Float, _ y: Float, _ w: Float, _ h: Float) -> Bool {
        mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h
    }

    private func overCircle(_ x: Float, _ y: Float, _ diameter: Float) -> Bool {
        let disX = x - mouseX
        let disY = y - mouseY
        return (sq(disX) + sq(disY)).squareRoot() < diameter / 2
    }
}
