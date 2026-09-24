import mokume

/// Processing の [Linear](https://processing.org/examples/linear/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
final class Linear: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Linear")

    private var a: Float = 0

    func setup() {
        stroke(255)
        a = height / 2
    }

    func draw() {
        background(51)
        line(0, a, width, a)
        a = a - 0.5
        if a < 0 { a = height }
    }
}
