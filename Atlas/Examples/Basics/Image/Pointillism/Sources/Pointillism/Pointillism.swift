import mokume
import Support

/// Processing の [Pointillism](https://processing.org/examples/pointillism/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。半分だけ。** `map()` が無いのはそのとおりだが、
/// **`fill(pix, 128)` — 色に後から透かしを足す形が無い**。`LinearRGBA` の `alpha` を
/// 書き換えて渡し直すことになる。
///
/// 乱数で置き場を選ぶので **画素では比べられない。**
final class Pointillism: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Pointillism")

    private var img: Image?
    private let smallPoint: Float = 4
    private let largePoint: Float = 40

    func setup() {
        img = try? loadImage(asset("Basics/Image/Pointillism", "moonwalk.jpg"))
        imageMode(.center)
        noStroke()
        background(255)
    }

    func draw() {
        guard let img else { return }
        let pointillize = map(mouseX, 0, width, smallPoint, largePoint)
        let x = Int(random(Float(img.width)))
        let y = Int(random(Float(img.height)))
        var pix = img.get(x, y)
        // 原典は `fill(pix, 128)`。**色に透かしを足す形が無い**
        pix.alpha = 128 / 255
        fill(pix)
        ellipse(Float(x), Float(y), pointillize, pointillize)
    }
}
