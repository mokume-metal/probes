import mokume

/// Processing の [Embedded Links](https://processing.org/examples/embeddedlinks/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ブラウザ向けの出力が主題)。絵は出る。**
/// `v0.6.0` で `mousePressed()` / `mouseMoved()` / `mouseDragged()` の口が入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた) ので、
/// 原典と同じ組み立てに戻した。
///
/// **残るのは `link()` でページを開く口が無いことだけ。** 押されたことは受け取れるが、
/// 開く先が無いので、そこで止まる — **口が 1 つ埋まっても主題は移らない**例である。
final class EmbeddedLinks: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Embedded Links")

    private var overButton = false

    func draw() {
        background(204)
        if overButton == true {
            fill(255)
        } else {
            noFill()
        }
        rect(105, 60, 75, 75)
        line(135, 105, 155, 85)
        line(140, 85, 155, 85)
        line(155, 85, 155, 100)
    }

    /// 原典の `void mousePressed()`。
    func mousePressed() {
        if overButton {
            // 原典はここで `link("http://www.processing.org")` を呼ぶ。**書けない**
        }
    }

    /// 原典の `void mouseMoved()`。
    func mouseMoved() {
        checkButtons()
    }

    /// 原典の `void mouseDragged()`。**引数は使わない** — 原典は動いた量ではなく
    /// いまの位置を見るので、`checkButtons()` が `mouseX` / `mouseY` を読む。
    func mouseDragged(deltaX: Float, deltaY: Float) {
        checkButtons()
    }

    /// 原典の `void checkButtons()`。
    private func checkButtons() {
        overButton = mouseX > 105 && mouseX < 180 && mouseY > 60 && mouseY < 135
    }
}
