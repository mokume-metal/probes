import mokume

/// Processing の [Noise 2D](https://processing.org/examples/noise2d/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `updatePixels()` が無い。
/// 書き込みそのものは届くが、**並びの形が違う** (原典は 1 次元の添字、mokume は 2 次元)。
/// `map()` も無いので面の外に書く。
final class Noise2D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Noise 2D")

    private let increment: Float = 0.02

    func draw() {
        loadPixels()

        var xoff: Float = 0.0
        let detail = map(mouseX, 0, width, 0.1, 0.6)
        noiseDetail(8, detail)

        // 面の x, y ごとに雑音の値を取り、明るさにする
        for x in 0..<Int(width) {
            xoff += increment
            var yoff: Float = 0.0
            for y in 0..<Int(height) {
                yoff += increment

                let bright = noise(xoff, yoff) * 255
                pixels[x, y] = color(bright)
            }
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない**
    }
}
