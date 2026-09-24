import mokume

/// Processing の [Variables](https://processing.org/examples/variables/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。`strokeCap(SQUARE)` は
/// `StrokeCap.square` へ名前が変わるだけで届く。原典は静止形なので `setup()` へ写す。
final class Variables: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Variables")

    func setup() {
        background(0)
        stroke(153)
        strokeWeight(4)
        strokeCap(.square)

        var a: Float = 50
        var b: Float = 120
        let c: Float = 180

        line(a, b, a + c, b)
        line(a, b + 10, a + c, b + 10)
        line(a, b + 20, a + c, b + 20)
        line(a, b + 30, a + c, b + 30)

        a = a + c
        b = height - b

        line(a, b, a + c, b)
        line(a, b + 10, a + c, b + 10)
        line(a, b + 20, a + c, b + 20)
        line(a, b + 30, a + c, b + 30)

        a = a + c
        b = height - b

        line(a, b, a + c, b)
        line(a, b + 10, a + c, b + 10)
        line(a, b + 20, a + c, b + 20)
        line(a, b + 30, a + c, b + 30)
    }
}
