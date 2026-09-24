import Foundation
import mokume

/// Processing の [Tickle](https://processing.org/examples/tickle/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`createFont` の口が無いので
/// システムの書体へ置き換える。`textWidth` / `textAscent` / `textDescent` は
/// 名前どおり届くので、字の大きさを測って当たり判定にするところは移せる。
///
/// **字形と乱数の両方が入る**ので、原典と画素では比べられない。
final class Tickle: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Tickle")

    private let message = "tickle"
    private var x: Float = 0
    private var y: Float = 0
    private var hr: Float = 0   // 字の横の半径
    private var vr: Float = 0   // 字の縦の半径

    func setup() {
        // 原典は `textFont(createFont("SourceCodePro-Regular.ttf", 36))`。**書体を読めない**
        textFont("Menlo")
        textSize(36)
        textAlign(.center, .center)

        hr = textWidth(message) / 2
        vr = (textAscent() + textDescent()) / 2
        noStroke()
        x = width / 2
        y = height / 2
    }

    func draw() {
        // 背景を消す代わりに、半透明の矩形を上から重ねて薄れさせる
        fill(204, 204, 204, 120)
        rect(0, 0, width, height)

        // 字の上にカーソルが来たら位置を動かす
        if abs(mouseX - x) < hr && abs(mouseY - y) < vr {
            x += random(-5, 5)
            y += random(-5, 5)
        }
        fill(0)
        text("tickle", x, y)
    }
}
