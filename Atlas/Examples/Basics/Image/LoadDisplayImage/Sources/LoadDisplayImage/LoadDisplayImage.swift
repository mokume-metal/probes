import mokume
import Support

/// Processing の [Load and Display](https://processing.org/examples/loaddisplayimage/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。ほぼ当たっている。** `loadImage` も `image` も名前どおり
/// 届く。違うのは `Image.width` が `Int` であることだけ (原典は `int` だが、`image()` に
/// 渡すところで暗黙に float になる)。
final class LoadDisplayImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Load and Display")

    private var img: Image?

    func setup() {
        // 絵はスケッチの data フォルダに無いと読めない
        img = try? loadImage(asset("Basics/Image/LoadDisplayImage", "moonwalk.jpg"))
    }

    func draw() {
        guard let img else { return }
        // そのままの大きさで (0,0) に置く
        image(img, 0, 0)
        // (0, height/2) に半分の大きさで置く
        image(img, 0, height / 2, Float(img.width) / 2, Float(img.height) / 2)
    }
}
