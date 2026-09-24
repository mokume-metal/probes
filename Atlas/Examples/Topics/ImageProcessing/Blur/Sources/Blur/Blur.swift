import mokume
import Support

/// Processing の [Blur](https://processing.org/examples/blur/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。** 止まるのは 3 つとも「書き方」で、
/// どれも書き直せば届く:
///
/// 1. **`img.pixels` の 1 次元の並びが無い** — `get(x, y)` で 1 画素ずつ引く。
///    原典の `pos = (y+ky)*img.width + (x+kx)` という掛け算が消える
/// 2. **`red()` / `green()` / `blue()` が返す空間が違う** — mokume の `LinearRGBA` は
///    線形の値を持つので、表示の値へ戻してから畳み込む (`Support/Processing.swift`)。
///    **戻さずに畳み込むと絵が暗くなる**
/// 3. **`updatePixels()` が無い** — 書き戻しの合図が要らない
///
/// **`v0.9.0` で `noLoop()` が入った** ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。
/// 原典どおり 1 度だけ畳み込んで止まるので、**毎フレーム 200 万回を回し続けることがなくなった。**
final class Blur: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Blur")

    private let v: Float = 1.0 / 9.0
    private var kernel: [[Float]] { [[v, v, v], [v, v, v], [v, v, v]] }
    private var img: Image?

    func setup() {
        img = try? loadImage(asset("Topics/Image Processing/Blur", "moon.jpg"))
        noLoop()
    }

    func draw() {
        guard let img else { return }
        image(img, 0, 0)
        // 原典は `img.loadPixels()`。**Image に並びが無い**ので要らない
        guard let blurImg = try? createImage(img.width, img.height) else { return }
        let k = kernel
        for y in 1..<(img.height - 1) {          // 上下の縁は飛ばす
            for x in 1..<(img.width - 1) {       // 左右の縁は飛ばす
                var sumRed: Float = 0
                var sumGreen: Float = 0
                var sumBlue: Float = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixel = img.get(x + kx, y + ky)
                        sumRed += k[ky + 1][kx + 1] * red(pixel)
                        sumGreen += k[ky + 1][kx + 1] * green(pixel)
                        sumBlue += k[ky + 1][kx + 1] * blue(pixel)
                    }
                }
                blurImg.set(x, y, color(sumRed, sumGreen, sumBlue))
            }
        }
        // 原典はここで `blurImg.updatePixels()` を呼ぶ。**合図の口が無い**
        image(blurImg, width / 2, 0)
    }
}
