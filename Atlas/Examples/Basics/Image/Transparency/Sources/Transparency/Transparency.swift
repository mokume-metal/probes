import mokume
import Support

/// Processing の [Transparency](https://processing.org/examples/transparency/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `tint(255, 127)` の**明るさ + 透かしの
/// 2 つ組**が書けないので `LinearRGBA` を組む。`Image.width` が `Int` なのも同じ。
final class Transparency: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Transparency")

    private var img: Image?
    private var offset: Float = 0
    private let easing: Float = 0.05

    func setup() {
        img = try? loadImage(asset("Basics/Image/Transparency", "moonwalk.jpg"))
    }

    func draw() {
        guard let img else { return }
        image(img, 0, 0)   // そのままの濃さで置く
        let dx = (mouseX - Float(img.width) / 2) - offset
        offset += dx * easing
        tint(255, 127)   // 半分の濃さで置く
        image(img, offset, 0)
    }
}
