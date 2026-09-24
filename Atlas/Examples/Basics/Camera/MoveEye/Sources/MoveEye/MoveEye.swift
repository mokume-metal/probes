import mokume

/// Processing の [Move Eye](https://processing.org/examples/moveeye/) を 1 行ずつ移したもの。
/// 原典は Simon Greenwold 作。
///
/// **台帳は `clean` と言った。外れている。** `camera()` の 9 引数はそのまま届き、
/// `size(640,360,P3D)` の第 3 引数は要らない (描き方のモードを持たないので落ちる) が、
/// **`line()` に立体の版が無い** — mokume の `line` は 4 引数だけで、原典の
/// `line(-100, 0, 0, 100, 0, 0)` に当たる形が無い。`beginShape(.lines)` と
/// 3 次元の `vertex` で書き下すことになり、原典の 1 行が 4 行になる。
/// **名前は当たるのに引数の数が違う**ので、名前しか見ない台帳には写らない。
final class MoveEye: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Move Eye")

    func setup() {
        fill(204)
    }

    func draw() {
        lights()
        background(0)

        // マウスの高さで視点を動かす
        camera(30.0, mouseY, 220.0,   // 目の位置
               0.0, 0.0, 0.0,         // 見る先
               0.0, 1.0, 0.0)         // 上の向き

        noStroke()
        box(90)
        stroke(255)
        // 原典は `line(-100, 0, 0, 100, 0, 0)` の 3 行。**立体の line が無い**ので、
        // 線の頂点列として書き下す
        beginShape(.lines)
        vertex(-100, 0, 0); vertex(100, 0, 0)
        vertex(0, -100, 0); vertex(0, 100, 0)
        vertex(0, 0, -100); vertex(0, 0, 100)
        endShape()
    }
}
