import mokume

/// Processing の [Loop](https://processing.org/examples/loop/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。`v0.6.0` で半分・`v0.9.0` で残り半分が埋まった。**
/// 原典の主題は「`noLoop()` で止め、押したら `loop()` で動かす」ことそのものである。
/// 押す側の口が `v0.6.0` で入り ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)、
/// 止める口と動かす口が `v0.9.0` で入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。
///
/// **これが「段階の違い」の見本である** — 同じ `blocked` でも、口が 1 つ増えれば動く例と、
/// 2 つ揃わないと動かない例がある。押す側だけ書けていた間は、押す前から線が流れていて
/// 主題が移らなかった。
final class Loop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Loop")

    private var y: Float = 180

    func setup() {
        stroke(255)
        noLoop()
    }

    func draw() {
        background(0)
        line(0, y, width, y)
        y = y - 1
        if y < 0 { y = height }
    }

    /// 原典の `void mousePressed() { loop(); }`。**綴りも中身も原典と同じ。**
    func mousePressed() {
        loop()
    }
}
