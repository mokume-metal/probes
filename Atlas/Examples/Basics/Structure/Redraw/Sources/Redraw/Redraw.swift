import mokume

/// Processing の [Redraw](https://processing.org/examples/redraw/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言い、`v0.7.0` まではここで止まっていた。`v0.9.0` で動く。**
/// 原典の主題は「止めておいて、押すたびに 1 枚だけ描き直す」ことで、`noLoop()` も
/// `redraw()` も無かったので線が流れ続けていた。両方とも `v0.9.0` で入った
/// ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。
///
/// **`redraw()` を呼べるのはスケッチの呼び出しの中からだけである** — `draw()` の中や
/// 別の Task から頼んでも効かない ([mokume#1322](https://github.com/mokume-metal/mokume/issues/1322))。この例は原典どおり
/// `mousePressed()` から呼ぶので、そこには当たらない。
///
/// `Loop` / `NoLoop` と合わせて、**進行を握る 3 本がそろって動くようになった**。
final class Redraw: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Redraw")

    private var y: Float = 0

    func setup() {
        stroke(255)
        noLoop()
        y = height * 0.5
    }

    func draw() {
        background(0)
        y = y - 4
        if y < 0 { y = height }
        line(0, y, width, y)
    }

    /// 原典の `void mousePressed() { redraw(); }`。**綴りも中身も原典と同じ。**
    func mousePressed() {
        redraw()
    }
}
