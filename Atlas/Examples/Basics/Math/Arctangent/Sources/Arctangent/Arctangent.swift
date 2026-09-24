import Foundation
import mokume

/// Processing の [Arctangent](https://processing.org/examples/arctangent/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。**
/// `ArrayObjects` と同じで、**自分で描けるクラスが書けない** — 原典の `Eye` は
/// `PApplet` の内側にいるので `fill` も `ellipse` も `pushMatrix` もそのまま呼べるが、
/// mokume の描く口は `Sketch` の上にあるので面を持ち回ることになる。
///
/// マウスで変わる例なので、窓を持たない書き出しでは `mouseX` / `mouseY` が 0 のまま撮れる。
final class Arctangent: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Arctangent")

    final class Eye {
        let x: Float
        let y: Float
        let size: Float
        var angle: Float = 0

        init(_ tx: Float, _ ty: Float, _ ts: Float) {
            x = tx
            y = ty
            size = ts
        }

        func update(_ mx: Float, _ my: Float) {
            angle = atan2(my - y, mx - x)
        }

        func display(on sketch: any Sketch) {
            sketch.pushMatrix()
            sketch.translate(x, y)
            sketch.fill(255)
            sketch.ellipse(0, 0, size, size)
            sketch.rotate(angle)
            sketch.fill(153, 204, 0)
            sketch.ellipse(size / 4, 0, size / 2, size / 2)
            sketch.popMatrix()
        }
    }

    private var e1 = Eye(250, 16, 120)
    private var e2 = Eye(164, 185, 80)
    private var e3 = Eye(420, 230, 220)

    func setup() {
        noStroke()
    }

    func draw() {
        background(102)

        e1.update(mouseX, mouseY)
        e2.update(mouseX, mouseY)
        e3.update(mouseX, mouseY)

        e1.display(on: self)
        e2.display(on: self)
        e3.display(on: self)
    }
}
