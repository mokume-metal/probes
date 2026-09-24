import mokume

/// Processing の [Create Graphics](https://processing.org/examples/creategraphics/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** `createGraphics` も `beginDraw` /
/// `endDraw` も `image` も名前どおりに届くが、**`createGraphics` は投げる**
/// (`throws(RenderFailure)`) ので、原典の 1 行が `try` を伴う。面を作れないことが
/// あるという事実は Processing の語彙に無い。
///
/// マウスで動く例なので、窓を持たない書き出しでは `mouseX` が 0 のまま撮れる。
final class CreateGraphics: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Create Graphics")

    private var pg: Canvas?

    func setup() {
        pg = try? createGraphics(400, 200)
    }

    func draw() {
        fill(0, 12)
        rect(0, 0, width, height)
        fill(255)
        noStroke()
        ellipse(mouseX, mouseY, 60, 60)

        guard let pg else { return }
        pg.beginDraw()
        pg.background(51)
        pg.noFill()
        pg.stroke(255)
        pg.ellipse(mouseX - 120, mouseY - 60, 60, 60)
        pg.endDraw()

        // 別に持った面を image() で表へ出す
        image(pg, 120, 60)
    }
}
