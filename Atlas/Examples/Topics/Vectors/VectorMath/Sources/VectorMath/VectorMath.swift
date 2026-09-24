import mokume
import Support

/// Processing の [Vector Math](https://processing.org/examples/vectormath/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** 原典は `sub` / `normalize` / `mult` の
/// 3 つを順に呼んでベクトルの算術を見せる例だが、**その 3 つに当たるメソッドが無い**
/// ので、引き算と長さで割る式に書き直すことになる。**例の主題そのものが薄くなる。**
final class VectorMath: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Vector Math")

    func draw() {
        background(0)

        // マウスを指すベクトル
        var mouse = SIMD2<Float>(mouseX, mouseY)

        // 面の中心を指すベクトル
        let center = SIMD2<Float>(width / 2, height / 2)

        // 中心を引いて、中心からマウスへ向くベクトルにする (原典は `mouse.sub(center)`)
        mouse -= center

        // 長さを 1 にする (原典は `mouse.normalize()`)
        let length = mag(mouse.x, mouse.y)
        if length > 0 { mouse /= length }

        // 長さを 150 倍する (原典は `mouse.mult(150)`)
        mouse *= 150
        translate(width / 2, height / 2)
        stroke(255)
        strokeWeight(4)
        line(0, 0, mouse.x, mouse.y)
    }
}
