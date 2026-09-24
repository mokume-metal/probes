import mokume

/// Processing の [Mouse Functions](https://processing.org/examples/mousefunctions/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` ではここで止まっていた。`v0.6.0` で動く。**
/// 原典の主題は `mousePressed()` / `mouseDragged()` / `mouseReleased()` の 3 つで箱を
/// 掴んで動かすことで、出来事を受ける口が 1 つも無かった頃は、触れているかどうかを
/// 見る `draw()` の側だけが移り、掴む側が丸ごと落ちていた
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
///
/// **`mouseDragged()` だけは形が違う。** mokume は `mouseDragged(deltaX:deltaY:)` と
/// **その 1 件で動いた量**を引数で渡す。この例は動いた量ではなく**いまの位置**から
/// 箱を置くので、引数は使わず `mouseX` / `mouseY` を読む (原典と同じ)。
final class MouseFunctions: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse Functions")

    private var bx: Float = 0
    private var by: Float = 0
    private let boxSize: Float = 75
    private var overBox = false
    private var locked = false
    private var xOffset: Float = 0.0
    private var yOffset: Float = 0.0

    func setup() {
        bx = width / 2.0
        by = height / 2.0
        rectMode(.radius)
    }

    func draw() {
        background(0)

        // 箱の上に来ているか
        if mouseX > bx - boxSize && mouseX < bx + boxSize
            && mouseY > by - boxSize && mouseY < by + boxSize {
            overBox = true
            if !locked {
                stroke(255)
                fill(153)
            }
        } else {
            stroke(153)
            fill(153)
            overBox = false
        }

        rect(bx, by, boxSize, boxSize)
    }

    /// 原典の `void mousePressed()`。
    func mousePressed() {
        if overBox {
            locked = true
            fill(255, 255, 255)
        } else {
            locked = false
        }
        xOffset = mouseX - bx
        yOffset = mouseY - by
    }

    /// 原典の `void mouseDragged()`。**引数は使わない** — 原典は動いた量ではなく
    /// いまの位置から箱を置くので、`mouseX` / `mouseY` をそのまま読む。
    func mouseDragged(deltaX: Float, deltaY: Float) {
        if locked {
            bx = mouseX - xOffset
            by = mouseY - yOffset
        }
    }

    /// 原典の `void mouseReleased()`。
    func mouseReleased() {
        locked = false
    }
}
