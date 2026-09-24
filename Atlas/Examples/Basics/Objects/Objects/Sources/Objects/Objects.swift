import Foundation
import mokume

/// Processing の [Objects](https://processing.org/examples/objects/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `fill(255, 204)` の**明るさ + 透かしの 2 つ組**が
/// 書けず、描く口が `Sketch` の上にあるので `display()` が面を受け取る。
final class Objects: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Objects")

    final class MRect {
        let w: Float        // 帯 1 本の幅
        var xpos: Float     // 横の位置
        let h: Float        // 高さ
        var ypos: Float     // 縦の位置
        let d: Float        // 帯どうしの間
        let t: Float        // 帯の数

        init(_ iw: Float, _ ixp: Float, _ ih: Float, _ iyp: Float, _ id: Float, _ it: Float) {
            w = iw
            xpos = ixp
            h = ih
            ypos = iyp
            d = id
            t = it
        }

        func move(_ posX: Float, _ posY: Float, _ damping: Float) {
            var dif = ypos - posY
            if abs(dif) > 1 { ypos -= dif / damping }
            dif = xpos - posX
            if abs(dif) > 1 { xpos -= dif / damping }
        }

        func display(on sketch: any Sketch) {
            for i in 0..<Int(t) {
                sketch.rect(xpos + (Float(i) * (d + w)), ypos, w, sketch.height * h)
            }
        }
    }

    private var r1: MRect?
    private var r2: MRect?
    private var r3: MRect?
    private var r4: MRect?

    func setup() {
        fill(255, 204)
        noStroke()
        r1 = MRect(1, 134.0, 0.532, 0.1 * height, 10.0, 60.0)
        r2 = MRect(2, 44.0, 0.166, 0.3 * height, 5.0, 50.0)
        r3 = MRect(2, 58.0, 0.332, 0.4 * height, 10.0, 35.0)
        r4 = MRect(1, 120.0, 0.0498, 0.9 * height, 15.0, 60.0)
    }

    func draw() {
        background(0)

        r1?.display(on: self)
        r2?.display(on: self)
        r3?.display(on: self)
        r4?.display(on: self)

        r1?.move(mouseX - (width / 2), mouseY + (height * 0.1), 30)
        r2?.move((mouseX + (width * 0.05)).truncatingRemainder(dividingBy: width), mouseY + (height * 0.025), 20)
        r3?.move(mouseX / 4, mouseY - (height * 0.025), 40)
        r4?.move(mouseX - (width / 2), (height - mouseY), 50)
    }
}
