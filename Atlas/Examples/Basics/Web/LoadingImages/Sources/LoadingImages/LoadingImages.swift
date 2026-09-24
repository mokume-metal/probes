import mokume

/// Processing の [Loading Images](https://processing.org/examples/loadingimages/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った。実際にはここで止まっている。**
/// 原典の主題は **`loadImage()` に URL を渡してネットワークから読む**ことで、
/// mokume の `loadImage` は手元のパスしか探さない (`ImageFile.candidates` は作業
/// ディレクトリと束の中を見るだけ)。**止まっているのはここだけ**で、`noLoop()` は
/// `v0.9.0` で入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。
///
/// **動くように書き替えていない** — 読めないので面は背景の黒のままになる。
final class LoadingImages: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Loading Images")

    private var img: Image?

    func setup() {
        // 原典は `loadImage("https://processing.org/img/processing-web.png")`。
        // **URL を渡す口が無い** — 手元のパスしか探さない
        img = nil
        noLoop()
    }

    func draw() {
        background(0)
        if let img {
            for i in 0..<5 {
                image(img, 0, Float(img.height * i))
            }
        }
    }
}
