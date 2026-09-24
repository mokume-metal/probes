import mokume
import Support

/// Processing の [Pixel Array](https://processing.org/examples/pixelarray/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。`v0.9.0` でも当たっている。歪みは 3 つのまま。**
/// `frameRate(30)` は走り出す前にしか決められず ([mokume#1323](https://github.com/mokume-metal/mokume/issues/1323))、
/// `mousePressed` / `keyPressed` は変数なので `isMousePressed` / `isKeyDown(_:)` へ名前が
/// 変わり、**`set(0, 0, img)` — 絵を面へ丸ごと貼る速い口が無い** (`image()` で置き換える)。
///
/// **[#723](https://github.com/mokume-metal/mokume/issues/723) は閉じたが、この例には効かない** —
/// あれが入れたのは出来事の口で、この例が読むのは「いま押されているか」のほうである。
/// **`keyPressed` の変数のほうはとくに歪む** — mokume の `isKeyDown(_:)` はキーを 1 つ
/// 名指しで問うので、「何かキーが押されているか」を聞く口が無い。
final class PixelArray: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Pixel Array")

    private var img: Image?
    private var direction: Float = 1
    private var signal: Float = 0

    func setup() {
        noFill()
        stroke(255)
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
        img = try? loadImage(asset("Topics/Image Processing/PixelArray", "sea.jpg"))
    }

    func draw() {
        guard let img else { return }
        if signal > Float(img.width * img.height - 1) || signal < 0 {
            direction = direction * -1
        }
        if isMousePressed {
            let mx = constrain(mouseX, 0, Float(img.width - 1))
            let my = constrain(mouseY, 0, Float(img.height - 1))
            signal = my * Float(img.width) + mx
        } else {
            signal += 0.33 * direction
        }
        let sx = Int(signal) % img.width
        let sy = Int(signal) / img.width
        // 原典は `keyPressed` — **どれでもよいからキーが押されているか**を見る変数。
        // mokume にあるのは `isKeyDown(_ key: Key)` だけで (`v0.6.0` で Int から Key 型に
        // なった)、キーを名指しせずに聞く口が無い。押されていない側に固定するしかない
        let anyKeyPressed = false
        if anyKeyPressed {
            // 原典は `set(0, 0, img)` — 絵を面へ貼る速い口。**無い**ので image() で置く
            image(img, 0, 0)
            point(Float(sx), Float(sy))
            rect(Float(sx) - 5, Float(sy) - 5, 10, 10)
        } else {
            background(img.get(sx, sy))
        }
    }
}
