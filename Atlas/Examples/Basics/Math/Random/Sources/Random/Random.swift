import mokume

/// Processing の [Random](https://processing.org/examples/random/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — `frameRate(2)` は走り出す前にしか
/// 決められないので `SketchSettings` へ移る。
///
/// 乱数そのものが主題なので、原典と mokume で数列が違う。**画素では比べられない。**
final class Random: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 2, title: "Random")

    func setup() {
        background(0)
        strokeWeight(20)
        // 原典はここで `frameRate(2)` を呼ぶ。settings へ移した
    }

    func draw() {
        for i in 0..<Int(width) {
            let r = random(255)
            stroke(r)
            line(Float(i), 0, Float(i), height)
        }
    }
}
