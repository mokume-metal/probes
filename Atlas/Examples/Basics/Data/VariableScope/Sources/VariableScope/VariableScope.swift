import mokume

/// Processing の [Variable Scope](https://processing.org/examples/variablescope/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
///
/// 例の主題である**内側の名前が外側を隠す**ところは Swift でもそのまま書ける。
final class VariableScope: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Variable Scope")

    /// 全体で使える変数 "a"
    private let a: Float = 80

    func setup() {
        background(0)
        stroke(255)
        noLoop()
    }

    func draw() {
        // 全体の "a" で線を引く
        line(a, 0, a, height)

        // for の中だけで通じる新しい "a"
        for a in stride(from: Float(120), to: 200, by: 2) {
            line(a, 0, a, height)
        }

        // draw の中だけで通じる新しい "a"
        let a: Float = 300
        line(a, 0, a, height)

        drawAnotherLine()
        drawYetAnotherLine()
    }

    private func drawAnotherLine() {
        // このメソッドの中だけで通じる "a"
        let a: Float = 320
        line(a, 0, a, height)
    }

    private func drawYetAnotherLine() {
        // 新しい "a" を作っていないので、全体の "a" (80) で引かれる
        line(a + 2, 0, a + 2, height)
    }
}
