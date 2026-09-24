import mokume

/// Processing の [Double Random](https://processing.org/examples/doublerandom/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。
///
/// **台帳は `write-only` と言った。半分だけ。** `frameRate(1)` は走り出す前にしか
/// 決められないので `SketchSettings` へ移る (`bend`)。
///
/// 乱数を 2 段に重ねる例なので、原典と mokume で数列が違う。**画素では比べられない。**
final class DoubleRandom: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 1, title: "Double Random")

    private let totalPts = 300
    private var steps: Float { Float(totalPts + 1) }

    func setup() {
        stroke(255)
        // 原典はここで `frameRate(1)` を呼ぶ。settings へ移した
    }

    func draw() {
        background(0)
        var rand: Float = 0
        for i in 1..<Int(steps) {
            point((width / steps) * Float(i), (height / 2) + random(-rand, rand))
            rand += random(-5, 5)
        }
    }
}
