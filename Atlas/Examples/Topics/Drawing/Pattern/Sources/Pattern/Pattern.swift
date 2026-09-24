import Foundation
import mokume

/// Processing の [Pattern](https://processing.org/examples/pattern/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `pmouseX` / `pmouseY` は mokume も同じ名前で持つ。
/// マウスを動かさないと何も描かれないので、書き出しでは背景だけが残る。
final class Pattern: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Pattern")

    func setup() {
        background(102)
    }

    func draw() {
        // いまのマウスの位置と、1 つ前の位置を渡す
        variableEllipse(mouseX, mouseY, pmouseX, pmouseY)
    }

    private func variableEllipse(_ x: Float, _ y: Float, _ px: Float, _ py: Float) {
        let speed = abs(x - px) + abs(y - py)
        stroke(speed)
        ellipse(x, y, speed, speed)
    }
}
