import mokume

/// Processing の [Setup and Draw](https://processing.org/examples/setupdraw/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `setup()` と `draw()` の役割は mokume でも同じなので、そのまま置ける。
final class SetupDraw: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Setup and Draw")

    private var y: Float = 180

    // setup の中身は、はじめに 1 度だけ走る
    func setup() {
        stroke(255)
    }

    // draw の中身は止めるまで走り続ける。上から下へ順に読まれ、最後まで来たら
    // また 1 行目へ戻る
    func draw() {
        background(0)
        line(0, y, width, y)
        y = y - 1
        if y < 0 { y = height }
    }
}
