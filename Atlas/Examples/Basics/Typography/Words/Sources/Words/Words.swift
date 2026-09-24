import mokume

/// Processing の [Words](https://processing.org/examples/words/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`createFont` も `PFont.list()` も
/// 書けないので、システムの書体へ置き換える。`textAlign` は `HorizontalTextAlign` へ
/// 名前が変わるだけで届く。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class Words: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Words")

    func setup() {
        // 原典はここで `printArray(PFont.list())` と
        // `f = createFont("SpaceMono-Regular.ttf", 18)` を呼ぶ。**どちらも書けない**
        textFont("Menlo")
        textSize(18)
    }

    func draw() {
        background(102)
        textAlign(.right)
        drawType(width * 0.25)
        textAlign(.center)
        drawType(width * 0.5)
        textAlign(.left)
        drawType(width * 0.75)
    }

    private func drawType(_ x: Float) {
        line(x, 0, x, 65)
        line(x, 220, x, height)
        fill(0)
        text("ichi", x, 95)
        fill(51)
        text("ni", x, 130)
        fill(204)
        text("san", x, 165)
        fill(255)
        text("shi", x, 210)
    }
}
