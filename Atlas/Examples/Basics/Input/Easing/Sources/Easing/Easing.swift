import mokume

/// Processing の [Easing](https://processing.org/examples/easing/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている。** 色を 1 つも指定しない珍しい例なので、
/// **書き下しすら起きない** — 原典とまったく同じ行が並ぶ。
final class Easing: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Easing")

    private var x: Float = 0
    private var y: Float = 0
    private let easing: Float = 0.05

    func setup() {
        noStroke()
    }

    func draw() {
        background(51)

        let targetX = mouseX
        let dx = targetX - x
        x += dx * easing

        let targetY = mouseY
        let dy = targetY - y
        y += dy * easing

        ellipse(x, y, 66, 66)
    }
}
