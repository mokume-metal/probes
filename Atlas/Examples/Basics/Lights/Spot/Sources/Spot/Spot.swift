import mokume

/// Processing の [Spot](https://processing.org/examples/spot/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。歪みが 2 つ。**
/// `sphereDetail(60)` は状態ではなく `sphere(_:detail:)` の引数へ畳まれ、
/// `spotLight` の集中度 (600) は渡す口が無い。
final class Spot: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Spot")

    func setup() {
        noStroke()
        fill(204)
        // 原典はここで `sphereDetail(60)` を呼ぶ。mokume では sphere の引数へ移る
    }

    func draw() {
        background(0)

        // 球の下側を照らす
        directionalLight(51, 102, 126, 0, -1, 0)

        // 右上からの橙のスポット。**集中度 600 は渡せない**
        spotLight(204, 153, 0, 360, 160, 600, 0, 0, -1, angle: Float.pi / 2)

        // マウスを追うスポット
        spotLight(102, 153, 204, 360, mouseY, 600, 0, 0, -1, angle: Float.pi / 2)
        translate(width / 2, height / 2, 0)
        sphere(120, detail: 60)
    }
}
