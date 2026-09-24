import Foundation
import mokume
import Support

/// Processing の [Button](https://processing.org/examples/button/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` では半分止まっていた。`v0.6.0` で動く。**
/// 触れているかどうかを見る側 (`update`) は `draw()` の中のポーリングなのでそのまま
/// 移っていたが、**押して色を選ぶ `mousePressed()` の口が無かった**ので、押しても
/// 何も起きなかった ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
final class Button: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Button")

    private var rectX: Float = 0
    private var rectY: Float = 0
    private var circleX: Float = 0
    private var circleY: Float = 0
    private let rectSize: Float = 90
    private let circleSize: Float = 93
    private var rectColor = LinearRGBA.transparent
    private var circleColor = LinearRGBA.transparent
    private var baseColor = LinearRGBA.transparent
    private var rectHighlight = LinearRGBA.transparent
    private var circleHighlight = LinearRGBA.transparent
    private var currentColor = LinearRGBA.transparent
    private var rectOver = false
    private var circleOver = false

    func setup() {
        rectColor = color(0)
        rectHighlight = color(51)
        circleColor = color(255)
        circleHighlight = color(204)
        baseColor = color(102)
        currentColor = baseColor
        circleX = width / 2 + circleSize / 2 + 10
        circleY = height / 2
        rectX = width / 2 - rectSize - 10
        rectY = height / 2 - rectSize / 2
        ellipseMode(.center)
    }

    func draw() {
        update()
        background(currentColor)

        fill(rectOver ? rectHighlight : rectColor)
        stroke(255)
        rect(rectX, rectY, rectSize, rectSize)

        fill(circleOver ? circleHighlight : circleColor)
        stroke(0)
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

    /// 原典の `void mousePressed()` — 押した側の色を選ぶ。
    func mousePressed() {
        if circleOver {
            currentColor = circleColor
        }
        if rectOver {
            currentColor = rectColor
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
