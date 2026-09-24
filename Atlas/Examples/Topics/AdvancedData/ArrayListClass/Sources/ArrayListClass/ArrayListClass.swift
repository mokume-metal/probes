import mokume

/// Processing の [ArrayList Class](https://processing.org/examples/arraylistclass/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (データ構造が主題)。絵は出る。**
/// `ArrayList` は Swift の配列でそのまま書ける (`host`)。`mousePressed()` の口は
/// `v0.6.0` で入ったので ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)、
/// 押した場所へ足せる。残るのは `fill(0, life)` の**明るさ + 透かしの 2 つ組**。
final class ArrayListClass: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "ArrayList Class")

    final class Ball {
        var x: Float
        var y: Float
        var speed: Float = 0
        let gravity: Float = 0.1
        let w: Float
        var life: Float = 255

        init(_ tempX: Float, _ tempY: Float, _ tempW: Float) {
            x = tempX
            y = tempY
            w = tempW
        }

        func move(height: Float) {
            speed = speed + gravity
            y = y + speed
            if y > height {
                speed = speed * -0.8
                y = height
            }
        }

        func finished() -> Bool {
            life -= 1
            return life < 0
        }

        func display(on sketch: any Sketch) {
            sketch.fill(0, life)
            sketch.ellipse(x, y, w, w)
        }
    }

    private var balls: [Ball] = []
    private let ballWidth: Float = 48

    func setup() {
        noStroke()
        balls = [Ball(width / 2, 0, ballWidth)]
    }

    func draw() {
        background(255)
        // 消しながら回すので後ろから見る
        for i in stride(from: balls.count - 1, through: 0, by: -1) {
            balls[i].move(height: height)
            balls[i].display(on: self)
            if balls[i].finished() { balls.remove(at: i) }
        }
    }

    /// 原典の `void mousePressed()` — 押した場所へ 1 つ足す。
    func mousePressed() {
        balls.append(Ball(mouseX, mouseY, ballWidth))
    }
}
