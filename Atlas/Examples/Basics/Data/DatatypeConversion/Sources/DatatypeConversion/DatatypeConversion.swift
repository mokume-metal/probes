import mokume

/// Processing の [Datatype Conversion](https://processing.org/examples/datatypeconversion/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`createFont` は書けないので
/// システムの書体へ置き換える。**型の変換そのものは Swift でもそのまま書ける**が、
/// Java の `byte` は符号付き 8 ビットなので `Int8` を使う (原典が見せたい「32 になる」
/// はそのまま出る)。原典は静止形。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class DatatypeConversion: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Datatype Conversion")

    func setup() {
        background(0)
        noStroke()
        // 原典は `textFont(createFont("SourceCodePro-Regular.ttf", 24))`。**書体を読めない**
        textFont("Menlo")
        textSize(24)

        let c: Character = "A"           // 文字
        let f = Float(c.asciiValue ?? 0) // 小数。65.0 になる
        let i = Int(f * 1.4)             // 整数。91 になる
        let b = Int8(f / 2)              // 8 ビット。32 になる

        text("The value of variable c is \(c)", 50, 100)
        text("The value of variable f is \(f)", 50, 150)
        text("The value of variable i is \(i)", 50, 200)
        text("The value of variable b is \(b)", 50, 250)
    }
}
