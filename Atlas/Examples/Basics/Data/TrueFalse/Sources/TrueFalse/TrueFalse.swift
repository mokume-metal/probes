import mokume

/// Processing の [True/False](https://processing.org/examples/truefalse/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。原典は静止形なので
/// `setup()` へ写す。
final class TrueFalse: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "True/False")

    func setup() {
        var b = false

        background(0)
        stroke(255)

        let d = 20
        let middle = Int(width) / 2

        for i in stride(from: d, through: Int(width), by: d) {
            b = i < middle

            if b == true {
                // 縦の線
                line(Float(i), Float(d), Float(i), height - Float(d))
            }

            if b == false {
                // 横の線
                line(Float(middle), Float(i - middle + d), width - Float(d), Float(i - middle + d))
            }
        }
    }
}
