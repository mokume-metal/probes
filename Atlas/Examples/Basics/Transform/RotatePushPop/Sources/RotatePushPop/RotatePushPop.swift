import mokume

/// Processing の [Rotate Push Pop](https://processing.org/examples/rotatepushpop/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `map()` が無いので面の外に書く。
final class RotatePushPop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Rotate Push Pop")

    private var a: Float = 0                    // 回す角
    private let offset: Float = .pi / 24.0      // 箱ごとの角のずれ
    private let num = 12                        // 箱の数

    func setup() {
        noStroke()
    }

    func draw() {
        lights()

        background(0, 0, 26)
        translate(width / 2, height / 2)

        for i in 0..<num {
            let shade = map(Float(i), 0, Float(num - 1), 0, 255)
            pushMatrix()
            fill(shade)
            rotateY(a + offset * Float(i))
            rotateX(a / 2 + offset * Float(i))
            box(200)
            popMatrix()
        }

        a += 0.01
    }
}
