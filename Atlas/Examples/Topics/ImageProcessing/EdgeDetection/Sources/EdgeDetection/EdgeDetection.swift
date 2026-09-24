import mokume
import Support

/// Processing の [Edge Detection](https://processing.org/examples/edgedetection/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。** 止まるのは 3 つ:
/// `img.copy()` (絵を複製する口が無い)、`filter(GRAY)` (組み込みの効き目が無い)、
/// `updatePixels()`。**灰色にするところは自分で書けば済む**ので、絵は出る。
final class EdgeDetection: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Edge Detection")

    private let kernel: [[Float]] = [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]]
    private var img: Image?

    func setup() {
        img = try? loadImage(asset("Topics/Image Processing/EdgeDetection", "moon.jpg"))
        noLoop()
    }

    func draw() {
        guard let img else { return }
        image(img, 0, 0)

        // 縁の検出は灰色の絵に対して行う。原典は `img.copy()` と `filter(GRAY)` の
        // 2 行だが、**複製する口も組み込みの効き目も無い**ので自分で書く
        guard let grayImg = try? createImage(img.width, img.height) else { return }
        for y in 0..<img.height {
            for x in 0..<img.width {
                // `brightness()` は **0…100 の百分率**で返る (`v0.6.0`)。
                // 原典の `brightness()` は colorMode の上限 (既定 255) で返すので、
                // 灰色を作る `color(_:)` (0…255) へ渡す前に目盛りを直す
                grayImg.set(x, y, color(brightness(img.get(x, y)) * 2.55))
            }
        }

        guard let edgeImg = try? createImage(grayImg.width, grayImg.height) else { return }
        for y in 1..<(grayImg.height - 1) {
            for x in 1..<(grayImg.width - 1) {
                // 出力は 50% の灰色からのずれとして見せる (暗→明の移り変わりを残すため)
                var sum: Float = 128
                for ky in -1...1 {
                    for kx in -1...1 {
                        // 灰色なので赤も緑も青も同じ値
                        sum += kernel[ky + 1][kx + 1] * blue(grayImg.get(x + kx, y + ky))
                    }
                }
                edgeImg.set(x, y, color(sum))
            }
        }
        // 原典はここで `edgeImg.updatePixels()` を呼ぶ。**書けない**
        image(edgeImg, width / 2, 0)
    }
}
