import mokume

/// Processing の [Noise 3D](https://processing.org/examples/noise3d/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `updatePixels()` が無い。
/// `frameRate(30)` も走り出す前にしか決められないので `SketchSettings` へ移る。
final class Noise3D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Noise 3D")

    private let increment: Float = 0.01
    /// 雑音の 3 つ目の引数。1 周ごとに進める
    private var zoff: Float = 0.0
    private let zincrement: Float = 0.02

    func draw() {
        loadPixels()

        var xoff: Float = 0.0

        for x in 0..<Int(width) {
            xoff += increment
            var yoff: Float = 0.0
            for y in 0..<Int(height) {
                yoff += increment

                let bright = noise(xoff, yoff, zoff) * 255
                pixels[x, y] = color(bright)
            }
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない**

        zoff += zincrement
    }
}
