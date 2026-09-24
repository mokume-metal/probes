import Foundation
import mokume

/// Processing の [Moving On Curves](https://processing.org/examples/movingoncurves/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` では押しても何も起きなかった。`v0.6.0` で動く** —
/// `mousePressed()` の出来事を受ける口が入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。押して行き先を
/// 変えるところが落ちるので、最初の 1 本の道すじを走ったまま止まる。
final class MovingOnCurves: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Moving On Curves")

    private var beginX: Float = 20.0    // 始まりの x
    private var beginY: Float = 10.0    // 始まりの y
    private var endX: Float = 570.0     // 終わりの x
    private var endY: Float = 320.0     // 終わりの y
    private var distX: Float = 0
    private var distY: Float = 0
    private let exponent: Float = 4     // 曲がり方を決める
    private var x: Float = 0.0
    private var y: Float = 0.0
    private let step: Float = 0.01      // 1 歩の大きさ
    private var pct: Float = 0.0        // 進んだ割合 (0.0 〜 1.0)

    func setup() {
        noStroke()
        distX = endX - beginX
        distY = endY - beginY
    }

    func draw() {
        fill(0, 2)
        rect(0, 0, width, height)
        pct += step
        if pct < 1.0 {
            x = beginX + (pct * distX)
            y = beginY + (pow(pct, exponent) * distY)
        }
        fill(255)
        ellipse(x, y, 20, 20)
    }

    /// 原典の `void mousePressed()` — 押した場所を新しい行き先にする。
    func mousePressed() {
        pct = 0.0
        beginX = x
        beginY = y
        endX = mouseX
        endY = mouseY
        distX = endX - beginX
        distY = endY - beginY
    }
}
