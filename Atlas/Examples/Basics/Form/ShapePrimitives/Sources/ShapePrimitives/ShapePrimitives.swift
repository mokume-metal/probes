import mokume

/// Processing の [Shape Primitives](https://processing.org/examples/shapeprimitives/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `triangle` / `quad` / `ellipse` / `arc` はすべて同じ名前・同じ引数の順で届く。原典は静止形。
final class ShapePrimitives: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Shape Primitives")

    func setup() {
        background(0)
        noStroke()
        fill(204)
        triangle(18, 18, 18, 360, 81, 360)
        fill(102)
        rect(81, 81, 63, 63)
        fill(204)
        quad(189, 18, 216, 18, 216, 360, 144, 360)
        fill(255)
        ellipse(252, 144, 72, 72)
        fill(204)
        triangle(288, 18, 351, 360, 288, 360)
        fill(255)
        arc(479, 300, 280, 280, Float.pi, Float.pi * 2)
    }
}
