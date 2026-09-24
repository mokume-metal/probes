import mokume

/// Processing の [Conditionals 2](https://processing.org/examples/conditionals2/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。** 語彙は当たり、詰まるのは Conditionals1 と同じ
/// 数値 1 つの灰色だけ。原典は静止形なので `setup()` へ写す。
final class Conditionals2: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Conditionals 2")

    func setup() {
        background(0)

        for i in stride(from: 2, to: Int(width) - 2, by: 2) {
            // 'i' が 20 で割り切れるとき
            if i % 20 == 0 {
                stroke(255)
                line(Float(i), 80, Float(i), height / 2)
            // 'i' が 10 で割り切れるとき
            } else if i % 10 == 0 {
                stroke(153)
                line(Float(i), 20, Float(i), 180)
            // 上のどちらでもないとき
            } else {
                stroke(102)
                line(Float(i), height / 2, Float(i), height - 20)
            }
        }
    }
}
