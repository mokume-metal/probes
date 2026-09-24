import mokume

/// Processing の [Rotate X Y](https://processing.org/examples/rotatexy/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `fill(204, 204)` の**明るさ + 透かしの 2 つ組**が
/// 書けない (`color(204, 204)` へ)。`TWO_PI` は Swift の `Float.pi * 2` で当たる。
final class RotateXY: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Rotate X Y")

    private var a: Float = 0.0
    private var rSize: Float = 0   // 矩形の大きさ

    func setup() {
        rSize = width / 6
        noStroke()
        fill(204, 204)
    }

    func draw() {
        background(126)

        a += 0.005
        if a > .pi * 2 { a = 0.0 }

        translate(width / 2, height / 2)

        rotateX(a)
        rotateY(a * 2.0)
        fill(255)
        rect(-rSize, -rSize, rSize * 2, rSize * 2)

        rotateX(a * 1.001)
        rotateY(a * 2.002)
        fill(0)
        rect(-rSize, -rSize, rSize * 2, rSize * 2)
    }
}
