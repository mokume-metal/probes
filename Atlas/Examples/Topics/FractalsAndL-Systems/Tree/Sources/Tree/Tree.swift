import mokume

/// Processing の [Tree](https://processing.org/examples/tree/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — 原典は `draw()` の中で `frameRate(30)` を
/// 呼ぶが、mokume では走り出す前にしか決められないので `SketchSettings` へ移る。
/// `radians()` も無いので面の外に書く。
final class Tree: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Tree")

    private var theta: Float = 0

    func draw() {
        background(0)
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
        stroke(255)
        // マウスの位置から 0〜90 度を選ぶ
        let a = (mouseX / width) * 90
        theta = radians(a)
        // 面の下から木を始める
        translate(width / 2, height)
        line(0, 0, 0, -120)
        translate(0, -120)
        branch(120)
    }

    private func branch(_ h: Float) {
        // 枝は前のものの 3 分の 2 の長さになる
        let h = h * 0.66

        // 再帰には必ず出口が要る。ここでは長さが 2 画素以下になったら止める
        if h > 2 {
            pushMatrix()
            rotate(theta)
            line(0, 0, 0, -h)
            translate(0, -h)
            branch(h)
            popMatrix()

            pushMatrix()
            rotate(-theta)
            line(0, 0, 0, -h)
            translate(0, -h)
            branch(h)
            popMatrix()
        }
    }
}
