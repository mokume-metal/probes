import mokume

/// Processing の [Inheritance](https://processing.org/examples/inheritance/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。** 継承そのものは Swift でもそのまま書けるが、
/// **描く口が `Sketch` の上にある**ので、子クラスの `display()` が面を受け取る形になる。
final class Inheritance: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Inheritance")

    class Spin {
        var x: Float
        var y: Float
        var speed: Float
        var angle: Float = 0.0

        init(_ xpos: Float, _ ypos: Float, _ s: Float) {
            x = xpos
            y = ypos
            speed = s
        }

        func update() {
            angle += speed
        }
    }

    final class SpinArm: Spin {
        func display(on sketch: any Sketch) {
            sketch.strokeWeight(1)
            sketch.stroke(0)
            sketch.pushMatrix()
            sketch.translate(x, y)
            angle += speed
            sketch.rotate(angle)
            sketch.line(0, 0, 165, 0)
            sketch.popMatrix()
        }
    }

    final class SpinSpots: Spin {
        let dim: Float

        init(_ x: Float, _ y: Float, _ s: Float, _ d: Float) {
            dim = d
            super.init(x, y, s)
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.pushMatrix()
            sketch.translate(x, y)
            angle += speed
            sketch.rotate(angle)
            sketch.ellipse(-dim / 2, 0, dim, dim)
            sketch.ellipse(dim / 2, 0, dim, dim)
            sketch.popMatrix()
        }
    }

    private var spots: SpinSpots?
    private var arm: SpinArm?

    func setup() {
        arm = SpinArm(width / 2, height / 2, 0.01)
        spots = SpinSpots(width / 2, height / 2, -0.02, 90.0)
    }

    func draw() {
        background(204)
        arm?.update()
        arm?.display(on: self)
        spots?.update()
        spots?.display(on: self)
    }
}
