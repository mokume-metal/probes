import mokume
import Support

/// Processing の [Interpolate](https://processing.org/examples/interpolate/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `lerp()` が無いので面の外に書く。
/// マウスへ寄っていく例なので、窓を持たない書き出しでは原点へ寄る。
final class Interpolate: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Interpolate")

    private var x: Float = 0
    private var y: Float = 0

    func setup() {
        noStroke()
    }

    func draw() {
        background(51)

        // lerp() は 2 つの数の間を、指定した割合の位置で取る。0.0 なら 1 つ目、
        // 0.5 ならちょうど半分。ここでは毎フレーム 5% ずつマウスへ寄る
        x = lerp(x, mouseX, 0.05)
        y = lerp(y, mouseY, 0.05)

        fill(255)
        stroke(255)
        ellipse(x, y, 66, 66)
    }
}
