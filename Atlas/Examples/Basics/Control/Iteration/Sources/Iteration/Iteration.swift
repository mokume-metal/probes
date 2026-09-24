import mokume

/// Processing の [Iteration](https://processing.org/examples/iteration/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。** 語彙は当たり、詰まるのは数値 1 つの灰色だけ。
final class Iteration: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Iteration")

    func setup() {
        let num = 14
        var y: Float = 0

        background(102)
        noStroke()

        // 白い帯
        fill(255)
        y = 60
        for _ in 0..<(num / 3) {
            rect(50, y, 475, 10)
            y += 20
        }

        // 灰色の帯
        fill(51)
        y = 40
        for _ in 0..<num {
            rect(405, y, 30, 10)
            y += 20
        }
        y = 50
        for _ in 0..<num {
            rect(425, y, 30, 10)
            y += 20
        }

        // 細い線
        y = 45
        fill(0)
        for _ in 0..<(num - 1) {
            rect(120, y, 40, 1)
            y += 20
        }
    }
}
