import mokume

/// Processing の [Mixture Grid](https://processing.org/examples/mixturegrid/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — `Mixture` と同じで `spotLight` の
/// 集中度が渡せない。
final class MixtureGrid: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mixture Grid")

    func setup() {
        noStroke()
    }

    func draw() {
        defineLights()
        background(0)

        for x in stride(from: Float(0), through: width, by: 60) {
            for y in stride(from: Float(0), through: height, by: 60) {
                pushMatrix()
                translate(x, y)
                rotateY(map(mouseX, 0, width, 0, Float.pi))
                rotateX(map(mouseY, 0, height, 0, Float.pi))
                box(90)
                popMatrix()
            }
        }
    }

    private func defineLights() {
        pointLight(150, 100, 0, 200, -150, 0)
        directionalLight(0, 102, 255, 1, 0, 0)
        // **原典の集中度 2 は渡せない**
        spotLight(255, 255, 109, 0, 40, 200, 0, -0.5, -0.5, angle: Float.pi / 2)
    }
}
