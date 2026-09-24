import mokume

/// Processing の [Mouse Signals](https://processing.org/examples/mousesignals/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** `mousePressed` は変数なので
/// `isMousePressed` へ、`noSmooth()` は書けない。
final class MouseSignals: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse Signals")

    private var xvals: [Float] = []
    private var yvals: [Float] = []
    private var bvals: [Float] = []

    func setup() {
        // 原典はここで `noSmooth()` を呼ぶ。**書けない**
        xvals = [Float](repeating: 0, count: Int(width))
        yvals = [Float](repeating: 0, count: Int(width))
        bvals = [Float](repeating: 0, count: Int(width))
    }

    func draw() {
        background(102)

        for i in 1..<Int(width) {
            xvals[i - 1] = xvals[i]
            yvals[i - 1] = yvals[i]
            bvals[i - 1] = bvals[i]
        }
        // 新しい値を末尾へ足す
        xvals[Int(width) - 1] = mouseX
        yvals[Int(width) - 1] = mouseY

        if isMousePressed == true {
            bvals[Int(width) - 1] = 0
        } else {
            bvals[Int(width) - 1] = height / 3
        }

        fill(255)
        noStroke()
        rect(0, height / 3, width, height / 3 + 1)
        for i in 1..<Int(width) {
            // x の値
            stroke(255)
            point(Float(i), map(xvals[i], 0, width, 0, height / 3 - 1))

            // y の値
            stroke(0)
            point(Float(i), height / 3 + yvals[i] / 3)

            // 押されたかどうか
            stroke(255)
            line(Float(i), (2 * height / 3) + bvals[i], Float(i), (2 * height / 3) + bvals[i - 1])
        }
    }
}
