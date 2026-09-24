import mokume

/// Processing の [Arm](https://processing.org/examples/arm/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `pushMatrix` / `popMatrix` / `translate` / `rotate` はすべて名前どおり届く。
final class Arm: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Arm")

    private var x: Float = 0
    private var y: Float = 0
    private var angle1: Float = 0.0
    private var angle2: Float = 0.0
    private let segLength: Float = 100

    func setup() {
        strokeWeight(30)
        stroke(255, 160)

        x = width * 0.3
        y = height * 0.5
    }

    func draw() {
        background(0)

        angle1 = (mouseX / width - 0.5) * -.pi
        angle2 = (mouseY / height - 0.5) * .pi

        pushMatrix()
        segment(x, y, angle1)
        segment(segLength, 0, angle2)
        popMatrix()
    }

    private func segment(_ x: Float, _ y: Float, _ a: Float) {
        translate(x, y)
        rotate(a)
        line(0, 0, segLength, 0)
    }
}
