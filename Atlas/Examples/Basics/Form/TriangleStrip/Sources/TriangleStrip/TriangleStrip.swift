import Foundation
import mokume

/// Processing の [Triangle Strip](https://processing.org/examples/trianglestrip/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。
///
/// **台帳は `bend` と言った。当たっている。** `beginShape(TRIANGLE_STRIP)` に当たる
/// 綴りが無く、`VertexKind` は `.polygon` / `.points` / `.lines` / `.triangles` の 4 つ
/// だけ ([#882](https://github.com/mokume-metal/mokume/issues/882))。**帯を三角形へ
/// 畳むと、頂点が 2 度・3 度と重複して並ぶ** — 原典の「前の 2 点と次の 1 点で 1 枚」と
/// いう読み方が消える。
///
/// works の [Ring](https://github.com/mokume-metal/works/tree/main/Ring) が同じ例を p5 から移して踏んだ場所である。
final class TriangleStrip: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Triangle Strip")

    private var x: Float = 0
    private var y: Float = 0
    private let outsideRadius: Float = 150
    private let insideRadius: Float = 100

    func setup() {
        background(204)
        x = width / 2
        y = height / 2
    }

    func draw() {
        background(204)

        let numPoints = Int(map(mouseX, 0, width, 6, 60))
        var angle: Float = 0
        let angleStep = 180.0 / Float(numPoints)

        // 原典は `beginShape(TRIANGLE_STRIP)` で頂点を 1 列に並べるだけ。**帯が無い**ので
        // 頂点を溜めてから、3 つずつ重ねた三角形として書き直す
        var points: [(Float, Float)] = []
        for _ in 0...numPoints {
            points.append((x + cos(radians(angle)) * outsideRadius,
                           y + sin(radians(angle)) * outsideRadius))
            angle += angleStep
            points.append((x + cos(radians(angle)) * insideRadius,
                           y + sin(radians(angle)) * insideRadius))
            angle += angleStep
        }

        beginShape(.triangles)
        for i in 0..<max(0, points.count - 2) {
            for p in [points[i], points[i + 1], points[i + 2]] { vertex(p.0, p.1) }
        }
        endShape()
    }
}
