import mokume

/// Processing の [Create Image](https://processing.org/examples/createimage/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。**`createImage(230, 230, ARGB)` の
/// **第 3 引数 (形式) が無く** (mokume の絵は常に透かしを持つ)、`img.pixels` の
/// **1 次元の並びも無い** — `set(x, y, color)` で 1 画素ずつ置くことになる。
final class CreateImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Create Image")

    private var img: Image?

    func setup() {
        // 原典は `createImage(230, 230, ARGB)`。**形式の引数は無い**
        guard let picture = try? createImage(230, 230) else { return }
        let count = picture.width * picture.height
        for i in 0..<count {
            let a = map(Float(i), 0, Float(count), 255, 0)
            // 原典は `img.pixels[i] = color(0, 153, 204, a)`。**1 次元の並びが無い**
            picture.set(i % picture.width, i / picture.width, color(0, 153, 204, a))
        }
        img = picture
    }

    func draw() {
        background(0)
        guard let img else { return }
        image(img, 90, 80)
        image(img, mouseX - Float(img.width) / 2, mouseY - Float(img.height) / 2)
    }
}
