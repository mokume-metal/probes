import mokume

/// Processing の [Conditionals 1](https://processing.org/examples/conditionals1/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ当たっている。**
/// 語彙は 4 つとも mokume にあるが、`stroke(255)` と `stroke(153)` の**数値 1 つの灰色**が
/// 書けないので `color(_:)` を通す (`Support/Processing.swift`)。Mouse2D が
/// `background(51)` で踏んだのと同じ場所で、名前しか見ない台帳には写らない。
///
/// 原典は setup も draw も書かない**静止形**で、上から下へ 1 度だけ走る。mokume には
/// 進行を止める口が無いが、`setup()` は 1 度しか呼ばれないので、そこへ写せば同じになる
/// (`draw()` は書かない = 何もしない既定が効く)。
final class Conditionals1: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Conditionals 1")

    func setup() {
        background(0)

        for i in stride(from: 10, to: Int(width), by: 10) {
            // 'i' が 20 で割り切れれば 1 本目、そうでなければ 2 本目を引く
            if i % 20 == 0 {
                stroke(255)
                line(Float(i), 80, Float(i), height / 2)
            } else {
                stroke(153)
                line(Float(i), 20, Float(i), 180)
            }
        }
    }
}
