import mokume
import Support

/// Processing の [Linear Gradient](https://processing.org/examples/lineargradient/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
/// `lerpColor()` も `map()` も無いので面の外に書く。**混ぜる空間が違う**ので、
/// 原典 (表示値のまま混ぜる) と中間の色がずれる。
final class LinearGradient: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Linear Gradient")

    private enum Axis { case x, y }

    private var b1 = LinearRGBA.transparent
    private var b2 = LinearRGBA.transparent
    private var c1 = LinearRGBA.transparent
    private var c2 = LinearRGBA.transparent

    func setup() {
        b1 = color(255)
        b2 = color(0)
        c1 = color(204, 102, 0)
        c2 = color(0, 102, 153)
        noLoop()
    }

    func draw() {
        // 背景
        setGradient(0, 0, width / 2, height, b1, b2, .x)
        setGradient(width / 2, 0, width / 2, height, b2, b1, .x)
        // 手前
        setGradient(50, 90, 540, 80, c1, c2, .y)
        setGradient(50, 190, 540, 80, c2, c1, .x)
    }

    private func setGradient(_ x: Float, _ y: Float, _ w: Float, _ h: Float,
                             _ c1: LinearRGBA, _ c2: LinearRGBA, _ axis: Axis) {
        noFill()

        if axis == .y {   // 上から下へ
            for i in stride(from: y, through: y + h, by: 1) {
                let inter = map(i, y, y + h, 0, 1)
                stroke(lerpColor(c1, c2, inter))
                line(x, i, x + w, i)
            }
        } else {          // 左から右へ
            for i in stride(from: x, through: x + w, by: 1) {
                let inter = map(i, x, x + w, 0, 1)
                stroke(lerpColor(c1, c2, inter))
                line(i, y, i, y + h)
            }
        }
    }
}
