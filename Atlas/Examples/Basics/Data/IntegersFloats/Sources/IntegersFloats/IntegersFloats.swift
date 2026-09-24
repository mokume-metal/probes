import mokume

/// Processing の [Integers Floats](https://processing.org/examples/integersfloats/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
///
/// **ここでは Java の `int` を写す。** Mouse2D では「端数が落ちるのは Java の型の都合で
/// Processing の語彙ではない」として写さなかったが、この例は**整数と小数の違いそのものが
/// 主題**なので、`a` は `Int`、`b` は `Float` のまま持つ。
final class IntegersFloats: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Integers Floats")

    private var a = 0        // 整数の変数
    private var b: Float = 0 // 小数の変数

    func setup() {
        stroke(255)
    }

    func draw() {
        background(0)

        a = a + 1
        b = b + 0.2
        line(Float(a), 0, Float(a), height / 2)
        line(b, height / 2, b, height)

        if Float(a) > width { a = 0 }
        if b > width { b = 0 }
    }
}
