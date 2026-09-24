import mokume

/// Processing の [Multiple Constructors](https://processing.org/examples/multipleconstructors/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
/// **引数の無い作り方が面の大きさを読む**ので、`width` を渡す形になった (mokume では
/// クラスの側から面が見えない)。
final class MultipleConstructors: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Multiple Constructors")

    final class Spot {
        var x: Float
        var y: Float
        var radius: Float

        /// 1 つ目の作り方。既定の値を入れる
        init(width: Float, height: Float) {
            radius = 40
            x = width * 0.25
            y = height * 0.5
        }

        /// 2 つ目の作り方。引数で入れる
        init(_ xpos: Float, _ ypos: Float, _ r: Float) {
            x = xpos
            y = ypos
            radius = r
        }

        func display(on sketch: any Sketch) {
            sketch.ellipse(x, y, radius * 2, radius * 2)
        }
    }

    private var sp1: Spot?
    private var sp2: Spot?

    func setup() {
        background(204)
        noLoop()
        sp1 = Spot(width: width, height: height)
        sp2 = Spot(width * 0.5, height * 0.5, 120)
    }

    func draw() {
        sp1?.display(on: self)
        sp2?.display(on: self)
    }
}
