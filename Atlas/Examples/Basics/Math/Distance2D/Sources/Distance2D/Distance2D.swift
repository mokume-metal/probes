import mokume
import Support

/// Processing の [Distance 2D](https://processing.org/examples/distance2d/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `dist()` が無いので面の外に書く
/// (`Support/Processing.swift`)。10 本の例がこれを要求する。
final class Distance2D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Distance 2D")

    private var maxDistance: Float = 0

    func setup() {
        noStroke()
        maxDistance = dist(0, 0, width, height)
    }

    func draw() {
        background(0)

        for i in stride(from: Float(0), through: width, by: 20) {
            for j in stride(from: Float(0), through: height, by: 20) {
                var size = dist(mouseX, mouseY, i, j)
                size = size / maxDistance * 66
                ellipse(i, j, size, size)
            }
        }
    }
}
