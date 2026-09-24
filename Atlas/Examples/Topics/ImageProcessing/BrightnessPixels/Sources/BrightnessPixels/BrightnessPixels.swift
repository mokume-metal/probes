import mokume
import Support

/// Processing の [Brightness](https://processing.org/examples/brightnesspixels/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`updatePixels()` が無いのと、
/// **面の `pixels` が 2 次元の添字を取る**こと (原典は `pixels[y*width + x]`)。
/// `dist()` / `constrain()` も無いので面の外に書く。`frameRate(30)` は settings へ。
final class BrightnessPixels: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Brightness")

    private var img: Image?

    func setup() {
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
        img = try? loadImage(asset("Topics/Image Processing/BrightnessPixels", "moon-wide.jpg"))
        // 原典は `img.loadPixels()` と `loadPixels()` を 1 度だけ呼ぶ
        loadPixels()
    }

    func draw() {
        guard let img else { return }
        for x in 0..<min(img.width, Int(width)) {
            for y in 0..<min(img.height, Int(height)) {
                // 原典は `loc = x + y*img.width` で 1 次元へ畳む。**2 次元の添字で引く**
                var r = red(img.get(x, y))
                // マウスからの近さで明るさを変える
                let maxdist: Float = 50
                let d = dist(Float(x), Float(y), mouseX, mouseY)
                let adjustbrightness = 255 * (maxdist - d) / maxdist
                r += adjustbrightness
                r = constrain(r, 0, 255)
                pixels[x, y] = color(r)
            }
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない**
    }
}
