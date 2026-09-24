import mokume

/// Processing の [Text Rotation](https://processing.org/examples/textrotation/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`createFont` は書けないので
/// システムの書体へ置き換える。`radians()` も無いので面の外に書く。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class TextRotation: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Text Rotation")

    private var angleRotate: Float = 0.0

    func setup() {
        background(0)
        // 原典はここで `f = createFont("SourceCodePro-Regular.ttf", 18)`。**書けない**
        textFont("Menlo")
        textSize(18)
    }

    func draw() {
        background(0)
        strokeWeight(1)
        stroke(153)
        pushMatrix()
        let angle1 = radians(45)
        translate(100, 180)
        rotate(angle1)
        text("45 DEGREES", 0, 0)
        line(0, 0, 150, 0)
        popMatrix()

        pushMatrix()
        let angle2 = radians(270)
        translate(200, 180)
        rotate(angle2)
        text("270 DEGREES", 0, 0)
        line(0, 0, 150, 0)
        popMatrix()

        pushMatrix()
        translate(440, 180)
        rotate(radians(angleRotate))
        text("\(Int(angleRotate) % 360) DEGREES", 0, 0)
        line(0, 0, 150, 0)
        popMatrix()

        angleRotate += 0.25
        stroke(255, 0, 0)
        strokeWeight(4)
        point(100, 180)
        point(200, 180)
        point(440, 180)
    }
}
