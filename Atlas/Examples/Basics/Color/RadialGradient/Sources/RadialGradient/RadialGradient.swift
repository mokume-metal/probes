import mokume

/// Processing の [Radial Gradient](https://processing.org/examples/radialgradient/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。`v0.6.0` で歪みが 3 つから 2 つに減った。**
/// `colorMode(HSB, 360, 100, 100)` の**目盛りがそのまま mokume の目盛り**なので、
/// 色は原典の数のまま書ける。残るのは `frameRate(1)` が走り出す前にしか決められない
/// ことと、`ellipseMode(RADIUS)` が `ShapeMode.radius` へ名前が変わることの 2 つ。
///
/// 乱数で色相を選ぶので **画素では比べられない。**
final class RadialGradient: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 1, title: "Radial Gradient")

    private var dim: Float = 0

    func setup() {
        dim = width / 2
        background(0)
        // 原典はここで `colorMode(HSB, 360, 100, 100)` を呼ぶ。**目盛りを切り替える
        // 状態は持たない**ので、呼ぶ 1 行ごとに目盛りを名乗る (下の `color(hue:…)`)。
        // この例は原典の目盛りが mokume の目盛りと同じなので、数は 1 つも変わらない
        noStroke()
        ellipseMode(.radius)
        // 原典はここで `frameRate(1)` を呼ぶ。settings へ移した
    }

    func draw() {
        background(0)
        for x in stride(from: Float(0), through: width, by: dim) {
            drawGradient(x, height / 2)
        }
    }

    private func drawGradient(_ x: Float, _ y: Float) {
        let radius = Int(dim / 2)
        var h = random(0, 360)
        for r in stride(from: radius, to: 0, by: -1) {
            fill(color(hue: h, saturation: 90, brightness: 90))
            ellipse(x, y, Float(r), Float(r))
            h = (h + 1).truncatingRemainder(dividingBy: 360)
        }
    }
}
