import mokume

/// Processing の [Operator Precedence](https://processing.org/examples/operatorprecedence/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// 演算子の優先順位は Swift でも同じ順なので、原典の式をそのまま置ける。原典は静止形。
final class OperatorPrecedence: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Operator Precedence")

    func setup() {
        background(51)
        noFill()
        stroke(51)

        stroke(204)
        for i in stride(from: 0, to: Int(width) - 20, by: 4) {
            // 30 に 70 を足してから "i" と比べる
            if i > 30 + 70 {
                line(Float(i), 0, Float(i), 50)
            }
        }

        stroke(255)
        // 2 に 8 を掛けてから 4 を足す
        rect(4 + 2 * 8, 52, 290, 48)
        rect((4 + 2) * 8, 100, 290, 49)

        stroke(153)
        for i in stride(from: 0, to: Int(width), by: 2) {
            // 比べる式が先に、次に論理積、最後に論理和
            if i > 20 && i < 50 || i > 100 && i < Int(width) - 20 {
                line(Float(i), 151, Float(i), height - 1)
            }
        }
    }
}
