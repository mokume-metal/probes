import mokume
import Support

/// Processing の [Background Image](https://processing.org/examples/backgroundimage/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。** `background()` に**絵を渡す形が無い** —
/// mokume の `background` は `LinearRGBA` か `Surroundings` しか取らない。
/// `image(img, 0, 0)` で置き換えれば絵は同じになるが、**原典の「背景として敷く」という
/// 言い方が消える** (背景は毎フレーム塗り直すもの、という約束が無くなる)。
final class BackgroundImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Background Image")

    private var bg: Image?
    private var y: Float = 0

    func setup() {
        // 背景の絵は size() に渡した大きさと同じでなければならない (640 x 360)
        bg = try? loadImage(asset("Basics/Image/BackgroundImage", "moonwalk.jpg"))
    }

    func draw() {
        // 原典は `background(bg)`。**絵を渡す形が無い**ので置き直す
        if let bg { image(bg, 0, 0) }
        stroke(226, 204, 0)
        line(0, y, width, y)
        y += 1
        if y > height { y = 0 }
    }
}
