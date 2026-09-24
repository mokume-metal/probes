import mokume

/// Processing の [Noise Wave](https://processing.org/examples/noisewave/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `map()` が無いので面の外に書く。
/// `noise` / `beginShape` / `vertex` / `endShape(CLOSE)` はすべて名前どおり届く。
///
/// 雑音の数列が原典と違うので、**画素では比べられない。**
final class NoiseWave: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Noise Wave")

    private var yoff: Float = 0   // パーリン雑音の 2 つ目の軸

    func draw() {
        background(51)

        fill(255)
        // 波の点をつないだ多角形にする
        beginShape()

        var xoff: Float = 0

        for x in stride(from: Float(0), through: width, by: 10) {
            let y = map(noise(xoff, yoff), 0, 1, 200, 300)
            vertex(x, y)
            xoff += 0.05
        }
        yoff += 0.01
        vertex(width, height)
        vertex(0, height)
        endShape(.close)
    }
}
