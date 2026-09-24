import mokume

/// Processing の [Primitives 3D](https://processing.org/examples/primitives3d/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。**
/// **Processing の静止形を `setup()` へ写せるのは、光を使わない例だけだった** —
/// mokume は「光はフレームごとに置き直すもの」なので、`setup()` で置いた光はどの
/// フレームにも属さず無視される (走らせると警告が出る)。だからここだけ `draw()` へ
/// 写している。原典は 1 度で終わるが、mokume には止める口が無いので毎フレーム同じ絵を
/// 描き直すことになる (絵は変わらない)。
///
/// **原典を p5 で走らせられない 6 本のうちの 1 本。** site は代わりに 1280x720 の
/// 静止画を置いているので、比べるときはそれを縮めて使う (一致率は参考値になる)。
final class Primitives3D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Primitives 3D")

    func draw() {
        background(0)
        lights()
        noStroke()
        pushMatrix()
        translate(130, height / 2, 0)
        rotateY(1.25)
        rotateX(-0.4)
        box(100)
        popMatrix()
        noFill()
        stroke(255)
        pushMatrix()
        translate(500, height * 0.35, -200)
        sphere(280)
        popMatrix()
    }
}
