import mokume
import Support

/// Processing の [Alpha Mask](https://processing.org/examples/alphamask/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。** `img.mask(imgMask)` の口は
/// 無いが、`Image` は `get` / `set` を持つので**画素を 1 つずつ移し替えれば書ける**。
/// ただし原典の 1 行が二重の繰り返しになり、23 万回の呼び出しになる。
/// **`mask` の判定は `none` ではなく `write` が正しい** — 絵が出せないのではなく、
/// 書けば出る。
final class AlphaMask: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Alpha Mask")

    private var img: Image?

    func setup() {
        guard let picture = try? loadImage(asset("Basics/Image/Alphamask", "moonwalk.jpg")),
              let mask = try? loadImage(asset("Basics/Image/Alphamask", "mask.jpg"))
        else { return }
        // 原典は `img.mask(imgMask)` の 1 行。**切り抜く口が無い**ので、
        // 覆いの明るさを透かしとして 1 画素ずつ入れ直す
        for y in 0..<min(picture.height, mask.height) {
            for x in 0..<min(picture.width, mask.width) {
                var color = picture.get(x, y)
                color.alpha = mask.get(x, y).red
                picture.set(x, y, color)
            }
        }
        img = picture
        imageMode(.center)
    }

    func draw() {
        background(0, 102, 153)
        guard let img else { return }
        image(img, width / 2, height / 2)
        image(img, mouseX, mouseY)
    }
}
