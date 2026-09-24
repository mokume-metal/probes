import mokume

/// Processing の [Translate](https://processing.org/examples/translate/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
final class Translate: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Translate")

    private var x: Float = 0
    private let dim: Float = 80.0

    func setup() {
        noStroke()
    }

    func draw() {
        background(102)

        x = x + 0.8

        if x > width + dim { x = -dim }

        translate(x, height / 2 - dim / 2)
        fill(255)
        rect(-dim / 2, -dim / 2, dim, dim)

        // 変換は積み上がる。こちらの矩形は同じ x を渡しているのに 2 倍の速さで動く
        translate(x, dim)
        fill(0)
        rect(-dim / 2, -dim / 2, dim, dim)
    }
}
