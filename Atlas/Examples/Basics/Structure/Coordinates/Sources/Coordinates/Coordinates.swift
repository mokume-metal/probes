import mokume

/// Processing の [Coordinates](https://processing.org/examples/coordinates/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。原典は静止形。
final class Coordinates: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Coordinates")

    func setup() {
        // 背景を黒にして、塗りを消す
        background(0)
        noFill()

        // point() の 2 つの引数が位置を決める。1 つ目が x、2 つ目が y
        stroke(255)
        point(320, 180)
        point(320, 90)

        // 座標は点だけでなく、すべての形を描くのに使う。line() は最初の 2 つが
        // 一方の端、後の 2 つがもう一方の端
        stroke(0, 153, 255)
        line(0, 120, 640, 120)

        // rect() は最初の 2 つが左上の角、後の 2 つが幅と高さ
        stroke(255, 153, 0)
        rect(160, 36, 320, 288)
    }
}
