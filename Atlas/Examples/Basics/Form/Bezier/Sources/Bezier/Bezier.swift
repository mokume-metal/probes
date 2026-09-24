import mokume

/// Processing の [Bezier](https://processing.org/examples/bezier/) を移したもの。
///
/// **台帳は `bend` と言った。当たっている。** 単独で曲線を 1 本引く `bezier()` が無く、
/// 頂点として置く `bezierVertex` しか無いので、`beginShape` で包んで
/// 「始点を置いてから曲げる」形へ書き替える。原典の 1 行が 3 行になる。
final class Bezier: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Bezier")

    /// 原典の `background(0)`
    private static let ground = LinearRGBA.display(red: 0, green: 0, blue: 0)

    /// 原典の `stroke(255)`
    private static let ink = LinearRGBA.display(red: 1, green: 1, blue: 1)

    func setup() {
        stroke(Self.ink)
        noFill()
    }

    func draw() {
        background(Self.ground)
        for i in stride(from: Float(0), to: 200, by: 20) {
            // 原典は `bezier(x1, y1, cx1, cy1, cx2, cy2, x2, y2)` の 1 行。
            // **始点を vertex で置き、残り 6 つを bezierVertex へ渡す**形になる
            beginShape()
            vertex(mouseX - i / 2, 40 + i)
            bezierVertex(410, 20, 440, 300, 240 - i / 16, 300 + i / 8)
            endShape()
        }
    }
}
