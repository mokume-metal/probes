import mokume

/// Processing の [Orthographic](https://processing.org/examples/orthographic/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` では切り替えが消えていた。`v0.6.0` で動く。**
/// 押して切り替える口が入った ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
/// `ortho()` も `perspective()` も名前どおり届く。
///
/// **面の大きさが原典と site で違う** — 原典の `.pde` は `size(600, 360)` だが、
/// site の p5 は 640x360 に書き直している。移植は `.pde` に従う。
final class Orthographic: Sketch {
    var settings = SketchSettings(width: 600, height: 360, title: "Orthographic")

    private var showPerspective = false

    func setup() {
        noFill()
        fill(255)
        noStroke()
    }

    func draw() {
        lights()
        background(0)
        let far = map(mouseX, 0, width, 120, 400)
        if showPerspective == true {
            perspective(Float.pi / 3.0, width / height, 10, far)
        } else {
            ortho(-width / 2.0, width / 2.0, -height / 2.0, height / 2.0, 10, far)
        }
        translate(width / 2, height / 2, 0)
        rotateX(-Float.pi / 6)
        rotateY(Float.pi / 3)
        box(180)
    }

    /// 原典の `void mousePressed()` — 押すたびに投影を切り替える。
    func mousePressed() {
        showPerspective = !showPerspective
    }
}
