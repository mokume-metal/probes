import mokume

/// Processing の [Logical Operators](https://processing.org/examples/logicaloperators/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。** 語彙は当たり、詰まるのは数値 1 つの灰色だけ。
final class LogicalOperators: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Logical Operators")

    func setup() {
        background(126)

        var test = false

        for i in stride(from: 5, through: Int(height), by: 5) {
            let y = Float(i)

            // 論理積
            stroke(0)
            if i > 35 && i < 100 {
                line(width / 4, y, width / 2, y)
                test = false
            }

            // 論理和
            stroke(76)
            if i <= 35 || i >= 100 {
                line(width / 2, y, width, y)
                test = true
            }

            // 真かどうかを試す。`if (test)` は `if (test == true)` と同じ
            if test {
                stroke(0)
                point(width / 3, y)
            }

            // 偽かどうかを試す。`if (!test)` は `if (test == false)` と同じ
            if !test {
                stroke(255)
                point(width / 4, y)
            }
        }
    }
}
