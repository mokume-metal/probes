import mokume

/// Processing の [Functions](https://processing.org/examples/functions/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
final class Functions: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Functions")

    func setup() {
        background(51)
        noStroke()
        noLoop()
    }

    func draw() {
        drawTarget(width * 0.25, height * 0.4, 200, 4)
        drawTarget(width * 0.5, height * 0.5, 300, 10)
        drawTarget(width * 0.75, height * 0.3, 120, 6)
    }

    private func drawTarget(_ xloc: Float, _ yloc: Float, _ size: Int, _ num: Int) {
        // **原典の `255/num` は整数どうしの割り算**なので端数が落ちる (num=4 なら 63)。
        // 主題は関数の呼び分けであって整数の割り算ではないが、落とすと色が変わるので写す
        let grayvalues = Float(255 / num)
        let steps = Float(size / num)
        for i in 0..<num {
            fill(Float(i) * grayvalues)
            ellipse(xloc, yloc, Float(size) - Float(i) * steps, Float(size) - Float(i) * steps)
        }
    }
}
