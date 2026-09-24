import Foundation
import mokume

/// Processing の [Composite Objects](https://processing.org/examples/compositeobjects/) を 1 行ずつ移したもの。
/// 原典は 4 つのタブ (`CompositeObjects` / `Egg` / `EggRing` / `Ring`) に分かれている。
///
/// **台帳は `clean` と言った。外れている。** 語彙は当たるが、**自分で描けるクラスが
/// 書けない** — 原典の `Egg` / `Ring` は `PApplet` の内側にいるので `fill` も
/// `bezierVertex` もそのまま呼べる。mokume の描く口は `Sketch` の上にあるので、
/// 面を持ち回ることになる (`display(on:)`)。`scale(scalar)` の 1 引数版も無い。
final class CompositeObjects: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Composite Objects")

    /// 原典の `class Egg`。
    final class Egg {
        let x: Float
        let y: Float
        var tilt: Float = 0     // 左右の傾き
        var angle: Float = 0    // 傾きを決める角
        let scalar: Float       // 卵の高さ
        let range: Float

        init(_ xpos: Float, _ ypos: Float, _ r: Float, _ s: Float) {
            x = xpos
            y = ypos
            scalar = s / 100.0
            range = r
        }

        func wobble() {
            tilt = cos(angle) / range
            angle += 0.1
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.fill(255)
            sketch.pushMatrix()
            sketch.translate(x, y)
            sketch.rotate(tilt)
            sketch.scale(scalar, scalar)   // 原典は `scale(scalar)` の 1 引数
            sketch.beginShape()
            sketch.vertex(0, -100)
            sketch.bezierVertex(25, -100, 40, -65, 40, -40)
            sketch.bezierVertex(40, -15, 25, 0, 0, 0)
            sketch.bezierVertex(-25, 0, -40, -15, -40, -40)
            sketch.bezierVertex(-40, -65, -25, -100, 0, -100)
            sketch.endShape()
            sketch.popMatrix()
        }
    }

    /// 原典の `class Ring`。
    final class Ring {
        var x: Float = 0
        var y: Float = 0
        var diameter: Float = 0
        var on = false

        func start(_ xpos: Float, _ ypos: Float) {
            x = xpos
            y = ypos
            on = true
            diameter = 1
        }

        func grow(width: Float) {
            if on == true {
                diameter += 0.5
                if diameter > width * 2 { diameter = 0.0 }
            }
        }

        func display(on sketch: any Sketch) {
            if on == true {
                sketch.noFill()
                sketch.strokeWeight(4)
                sketch.stroke(155, 153)
                sketch.ellipse(x, y, diameter, diameter)
            }
        }
    }

    /// 原典の `class EggRing`。
    final class EggRing {
        let ovoid: Egg
        let circle = Ring()

        init(_ x: Float, _ y: Float, _ t: Float, _ sp: Float) {
            ovoid = Egg(x, y, t, sp)
            circle.start(x, y - sp / 2)
        }

        func transmit(on sketch: any Sketch) {
            ovoid.wobble()
            ovoid.display(on: sketch)
            circle.grow(width: sketch.width)
            circle.display(on: sketch)
            if circle.on == false { circle.on = true }
        }
    }

    private var er1: EggRing?
    private var er2: EggRing?

    func setup() {
        er1 = EggRing(width * 0.45, height * 0.5, 2, 120)
        er2 = EggRing(width * 0.65, height * 0.8, 10, 180)
    }

    func draw() {
        background(0)
        er1?.transmit(on: self)
        er2?.transmit(on: self)
    }
}
