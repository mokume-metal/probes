import mokume

/// Processing の [Mixture](https://processing.org/examples/mixture/) を 1 行ずつ移したもの。
/// 原典は Simon Greenwold 作。
///
/// **台帳は `bend` と言った。当たっている。**`spotLight` の最後の引数 (集中度) を
/// 渡す口が無く、mokume は角度までしか取らない。原典の光の絞り方がそのぶん緩む。
/// `map()` も無いので面の外に書く。
final class Mixture: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mixture")

    func setup() {
        noStroke()
    }

    func draw() {
        background(0)
        translate(width / 2, height / 2)

        // 右からの橙の点光源
        pointLight(150, 100, 0, 200, -150, 0)
        // 左からの青い平行光源
        directionalLight(0, 102, 255, 1, 0, 0)
        // 手前からの黄色いスポット。**原典の最後の引数 (集中度 2) は渡せない**
        spotLight(255, 255, 109, 0, 40, 200, 0, -0.5, -0.5, angle: Float.pi / 2)

        rotateY(map(mouseX, 0, width, 0, Float.pi))
        rotateX(map(mouseY, 0, height, 0, Float.pi))
        box(150)
    }
}
